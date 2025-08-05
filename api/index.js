// Vercel API for server monitoring
import { createClient } from 'redis';

export default async function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method === 'POST') {
    // Handle different session actions
    const { action } = req.body;
    
    switch (action) {
      case 'login':
        await handleLogin(req, res);
        break;
      case 'logout':
        await handleLogout(req, res);
        break;
      case 'heartbeat':
        await handleHeartbeat(req, res);
        break;
      default:
        // Default to heartbeat for backward compatibility
        await handleHeartbeat(req, res);
    }
  } else if (req.method === 'GET') {
    // Check if it's a test request
    if (req.query.test === 'teams') {
      await handleTeamsTest(req, res);
    } else {
      await handleStatus(req, res);
    }
  } else {
    res.status(405).json({ error: 'Method not allowed' });
  }
}

async function getRedisClient() {
  const redis = createClient({
    url: process.env.REDIS_URL || 'redis://localhost:6379'
  });
  
  if (!redis.isOpen) {
    await redis.connect();
  }
  
  return redis;
}

async function handleLogin(req, res) {
  try {
    const { serverId, username, sessionId } = req.body;

    if (!serverId || !username) {
      return res.status(400).json({ error: 'Missing serverId or username' });
    }

    const redis = await getRedisClient();
    const now = Date.now();
    const sessionKey = `session:${serverId}-${username}`;
    const serverKey = `server:${serverId}`;

    console.log(`Login request received: ${username} on ${serverId} at ${new Date().toLocaleString()}`);

    try {
      // Check for existing session
      const existingSession = await redis.get(sessionKey);
      
      if (existingSession) {
        console.log(`Session already exists for ${username} on ${serverId}, updating...`);
        const session = JSON.parse(existingSession);
        
        // Update existing session
        await redis.set(sessionKey, JSON.stringify({
          ...session,
          lastHeartbeat: now,
          lastLogin: now,
          sessionId: sessionId || session.sessionId,
          status: 'active'
        }), { EX: 300 }); // 5 minutes expiry
        
        res.status(200).json({ 
          success: true, 
          message: 'Session updated',
          sessionId: sessionId || session.sessionId
        });
      } else {
        // Create new session
        const newSession = {
          serverId,
          username,
          sessionId: sessionId || generateSessionId(),
          loginTime: now,
          lastHeartbeat: now,
          lastLogin: now,
          status: 'active'
        };

        await redis.set(sessionKey, JSON.stringify(newSession), { EX: 300 });
        await redis.sAdd(serverKey, sessionKey);

        // Send login notification
        sendTeamsNotification(createLoginMessage(username, serverId));
        console.log(`Login notification sent for: ${username} on ${serverId}`);

        res.status(200).json({ 
          success: true, 
          message: 'Login successful',
          sessionId: newSession.sessionId
        });
      }

    } catch (redisError) {
      console.error('Redis error in login:', redisError);
      res.status(500).json({ error: 'Redis error during login' });
    } finally {
      await redis.disconnect();
    }

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

async function handleLogout(req, res) {
  try {
    const { serverId, username, sessionId, reason } = req.body;

    if (!serverId || !username) {
      return res.status(400).json({ error: 'Missing serverId or username' });
    }

    const redis = await getRedisClient();
    const sessionKey = `session:${serverId}-${username}`;
    const serverKey = `server:${serverId}`;

    console.log(`Logout request received: ${username} on ${serverId} (reason: ${reason || 'manual'}) at ${new Date().toLocaleString()}`);

    try {
      // Check if session exists
      const sessionData = await redis.get(sessionKey);
      
      if (sessionData) {
        const session = JSON.parse(sessionData);
        
        // Send logout notification
        sendTeamsNotification(createLogoutMessage(username, serverId, reason));
        console.log(`Logout notification sent for: ${username} on ${serverId}`);
        
        // Remove session from storage
        await redis.del(sessionKey);
        await redis.sRem(serverKey, sessionKey);
        
        // Check if server is now free
        const remainingSessions = await redis.sMembers(serverKey);
        let serverHasUsers = false;
        
        for (const remainingSessionKey of remainingSessions) {
          const remainingSessionData = await redis.get(remainingSessionKey);
          if (remainingSessionData) {
            serverHasUsers = true;
            break;
          }
        }
        
        if (!serverHasUsers) {
          // Server is now free - send notification immediately
          console.log(`Server ${serverId} is now free`);
          sendTeamsNotification(createServerFreeMessage(serverId));
          console.log(`Server free notification sent for: ${serverId}`);
        }
        
        res.status(200).json({ 
          success: true, 
          message: 'Logout processed',
          serverFree: !serverHasUsers,
          reason: reason || 'manual'
        });
      } else {
        console.log(`Session not found for logout: ${username} on ${serverId}`);
        res.status(200).json({ 
          success: true, 
          message: 'Session not found'
        });
      }

    } catch (redisError) {
      console.error('Redis error in logout:', redisError);
      res.status(500).json({ error: 'Redis error during logout' });
    } finally {
      await redis.disconnect();
    }

  } catch (error) {
    console.error('Logout error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

async function handleHeartbeat(req, res) {
  try {
    const { serverId, username, cpu, memory, status, sessionId } = req.body;

    if (!serverId || !username) {
      return res.status(400).json({ error: 'Missing serverId or username' });
    }

    const redis = await getRedisClient();
    const now = Date.now();
    const sessionKey = `session:${serverId}-${username}`;
    const serverKey = `server:${serverId}`;

    console.log(`Heartbeat received: ${username} on ${serverId} at ${new Date().toLocaleString()}`);

    try {
      // Check for logout detection first
      await checkForLogouts(redis);

      // Check if this is a new session BEFORE updating
      const existingSession = await redis.get(sessionKey);
      const isNewSession = !existingSession;
      
      console.log(`Session check for ${username} on ${serverId}: existing=${!!existingSession}, isNew=${isNewSession}`);

      // Update heartbeat with robust expiry
      await redis.set(sessionKey, JSON.stringify({
        serverId,
        username,
        sessionId: sessionId || (existingSession ? JSON.parse(existingSession).sessionId : generateSessionId()),
        loginTime: existingSession ? JSON.parse(existingSession).loginTime : now,
        lastHeartbeat: now,
        status: status || 'active',
        cpu: cpu,
        memory: memory
      }), { EX: 180 }); // 3 minutes expiry for aggressive timing

      // Add to server's active sessions
      await redis.sAdd(serverKey, sessionKey);

      // Send Teams notification for NEW sessions only
      if (isNewSession) {
        console.log(`NEW SESSION DETECTED: ${username} on ${serverId}`);
        sendTeamsNotification(createLoginMessage(username, serverId));
        console.log(`Login notification sent for: ${username} on ${serverId}`);
      } else {
        console.log(`Updated session: ${username} on ${serverId}`);
      }

      // Get session count
      const sessionCount = await redis.sCard(serverKey);
      console.log(`Current sessions: ${sessionCount}`);

      res.status(200).json({ 
        success: true, 
        message: 'Heartbeat received',
        sessionCount: sessionCount
      });

    } catch (redisError) {
      console.error('Redis error:', redisError);
      // Fallback response if Redis is not available
      res.status(200).json({ 
        success: true, 
        message: 'Heartbeat received (Redis not available)',
        sessionCount: 0
      });
    } finally {
      await redis.disconnect();
    }

  } catch (error) {
    console.error('Heartbeat error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

async function handleStatus(req, res) {
  try {
    const { serverId } = req.query;
    
    console.log(`Status check at ${new Date().toLocaleString()}`);
    
    const redis = await getRedisClient();
    
    try {
      // Check for logouts
      await checkForLogouts(redis);

      if (serverId) {
        const serverKey = `server:${serverId}`;
        const sessionKeys = await redis.sMembers(serverKey);
        const activeSessions = [];

        for (const sessionKey of sessionKeys) {
          const sessionData = await redis.get(sessionKey);
          if (sessionData) {
            activeSessions.push(JSON.parse(sessionData));
          }
        }

        console.log(`Active sessions: ${activeSessions.length}`);

        res.status(200).json({
          activeSessions,
          totalSessions: activeSessions.length
        });
      } else {
        res.status(200).json({
          activeSessions: [],
          totalSessions: 0
        });
      }
    } catch (redisError) {
      console.error('Redis error in status:', redisError);
      res.status(200).json({
        activeSessions: [],
        totalSessions: 0,
        error: 'Redis not available'
      });
    } finally {
      await redis.disconnect();
    }

  } catch (error) {
    console.error('Status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

async function checkForLogouts(redis) {
  const now = Date.now();
  const timeout = 30 * 1000; // 30 seconds timeout for aggressive timing

  console.log(`Checking for logouts at ${new Date().toLocaleString()}`);

  try {
    // Get all server keys
    const serverKeys = await redis.keys('server:*');
    let loggedOffUsers = [];
    let serverIds = new Set();

    for (const serverKey of serverKeys) {
      const sessionKeys = await redis.sMembers(serverKey);
      
      for (const sessionKey of sessionKeys) {
        const sessionData = await redis.get(sessionKey);
        
        if (sessionData) {
          const session = JSON.parse(sessionData);
          const timeSinceLastHeartbeat = now - session.lastHeartbeat;
          console.log(`Session ${session.username} on ${session.serverId}: ${timeSinceLastHeartbeat}ms since last heartbeat`);
          
          if (timeSinceLastHeartbeat > timeout) {
            // Session timed out - user logged off
            console.log(`Session timed out: ${session.username} on ${session.serverId}`);
            loggedOffUsers.push(session);
            serverIds.add(session.serverId);
            
            // Remove session from storage
            await redis.del(sessionKey);
            await redis.sRem(serverKey, sessionKey);
            
            // Send Teams notification for logout
            sendTeamsNotification(createLogoutMessage(session.username, session.serverId, 'timeout'));
            console.log(`Logout notification sent for: ${session.username} on ${session.serverId}`);
          }
        } else {
          // Session doesn't exist, remove from server
          await redis.sRem(serverKey, sessionKey);
        }
      }
    }

    console.log(`Logged off users: ${loggedOffUsers.length}`);

    // Check if any servers are now free
    for (const serverId of serverIds) {
      const serverKey = `server:${serverId}`;
      const sessionKeys = await redis.sMembers(serverKey);
      let serverHasUsers = false;

      for (const sessionKey of sessionKeys) {
        const sessionData = await redis.get(sessionKey);
        if (sessionData) {
          serverHasUsers = true;
          break;
        }
      }
      
      if (!serverHasUsers) {
        // Server is now free - send notification immediately
        console.log(`Server ${serverId} is now free`);
        sendTeamsNotification(createServerFreeMessage(serverId));
        console.log(`Server free notification sent for: ${serverId}`);
      }
    }

  } catch (error) {
    console.error('Error checking for logouts:', error);
  }
}

async function handleTeamsTest(req, res) {
  try {
    console.log('Testing Teams notification...');
    
    // Only send one test message based on query parameter
    const testType = req.query.type || 'login';
    
    switch (testType) {
      case 'login':
        await sendTeamsNotification(createLoginMessage('test-user', 'TEST-SERVER'));
        break;
      case 'logout':
        await sendTeamsNotification(createLogoutMessage('test-user', 'TEST-SERVER', 'test'));
        break;
      case 'free':
        await sendTeamsNotification(createServerFreeMessage('TEST-SERVER'));
        break;
      default:
        await sendTeamsNotification(createLoginMessage('test-user', 'TEST-SERVER'));
    }
    
    res.status(200).json({ 
      success: true, 
      message: `Teams test notification sent: ${testType}`,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Teams test error:', error);
    res.status(500).json({ error: 'Teams test failed' });
  }
}

function generateSessionId() {
  return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

function createLoginMessage(username, serverId) {
  return {
    "text": `[LOGIN] ${username} logged into ${serverId} at ${new Date().toLocaleString()}`,
    "title": "Server Monitor - User Login"
  };
}

function createLogoutMessage(username, serverId, reason = 'manual') {
  return {
    "text": `[LOGOUT] ${username} logged off from ${serverId} at ${new Date().toLocaleString()} (${reason})`,
    "title": "Server Monitor - User Logout"
  };
}

function createServerFreeMessage(serverId) {
  return {
    "text": `[FREE] Server ${serverId} is now FREE at ${new Date().toLocaleString()}`,
    "title": "Server Monitor - Server Available"
  };
}

async function sendTeamsNotification(message) {
  const webhookUrl = process.env.TEAMS_WEBHOOK_URL;
  
  console.log('=== TEAMS NOTIFICATION DEBUG ===');
  console.log('Teams webhook URL configured:', !!webhookUrl);
  console.log('Teams webhook URL length:', webhookUrl ? webhookUrl.length : 0);
  console.log('Message to send:', JSON.stringify(message, null, 2));
  
  if (!webhookUrl) {
    console.log('Teams notification (no webhook configured):', message.text);
    return;
  }

  try {
    console.log('Sending Teams notification:', message.text);
    
    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(message)
    });
    
    console.log('Teams response status:', response.status);
    console.log('Teams response status text:', response.statusText);
    
    if (!response.ok) {
      const errorText = await response.text();
      console.error('Teams notification failed:', response.status, response.statusText, errorText);
    } else {
      console.log('Teams notification sent successfully:', message.text);
    }
  } catch (error) {
    console.error('Teams notification error:', error.message);
    console.error('Teams notification error stack:', error.stack);
  }
} 