// Vercel API for server monitoring
import { createClient } from 'redis';

// Configurable TTLs and timeouts to reduce flakiness
const SESSION_TTL_SEC = parseInt(process.env.SESSION_TTL_SEC || '180', 10); // Redis key expiry for sessions/active markers
const LOGOUT_TIMEOUT_SEC = parseInt(process.env.LOGOUT_TIMEOUT_SEC || '120', 10); // Inactivity threshold before considering logged out

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
      case 'check_logouts':
        await handleCheckLogouts(req, res);
        break;
      default:
        // Default to heartbeat for backward compatibility
        await handleHeartbeat(req, res);
    }
  } else if (req.method === 'GET') {
    // Check if it's a test request
    if (req.query.test === 'teams') {
      await handleTeamsTest(req, res);
    } else if (req.query.action === 'check_logouts') {
      await handleCheckLogouts(req, res);
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
          status: 'active',
          heartbeatCount: (session.heartbeatCount || 0) + 1,
          lastUpdate: new Date().toISOString()
        }), { EX: SESSION_TTL_SEC });
        
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

        await redis.set(sessionKey, JSON.stringify(newSession), { EX: SESSION_TTL_SEC });
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
    const activeKey = `active:${serverId}-${username}`;

    console.log(`Logout request received: ${username} on ${serverId} (reason: ${reason || 'manual'}) at ${new Date().toLocaleString()}`);

    try {
      // Check if session exists
      const sessionData = await redis.get(sessionKey);
      
      if (sessionData) {
        const session = JSON.parse(sessionData);
        
                 // Send logout notification with session duration
         const sessionDuration = Math.floor((Date.now() - session.loginTime) / 1000);
         sendTeamsNotification(createLogoutMessage(username, serverId, reason, sessionDuration));
         console.log(`Logout notification sent for: ${username} on ${serverId}`);
        
        // Remove session from storage
        await redis.del(sessionKey);
        await redis.del(activeKey);
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
    const activeKey = `active:${serverId}-${username}`;

    console.log(`Heartbeat received: ${username} on ${serverId} at ${new Date().toLocaleString()}`);

    try {
      // Check if this is a new session BEFORE updating
      const existingSession = await redis.get(sessionKey);
      const isNewSession = !existingSession;
      
      console.log(`Session check for ${username} on ${serverId}: existing=${!!existingSession}, isNew=${isNewSession}`);

             // Update heartbeat with robust expiry and more detailed tracking
       const sessionData = {
         serverId,
         username,
         sessionId: sessionId || (existingSession ? JSON.parse(existingSession).sessionId : generateSessionId()),
         loginTime: existingSession ? JSON.parse(existingSession).loginTime : now,
         lastHeartbeat: now,
         status: status || 'active',
         cpu: cpu,
         memory: memory,
         heartbeatCount: existingSession ? (JSON.parse(existingSession).heartbeatCount || 0) + 1 : 1,
         lastUpdate: new Date().toISOString(),
         sessionDuration: Math.floor((now - (existingSession ? JSON.parse(existingSession).loginTime : now)) / 1000) // Duration in seconds
       };
      
      await redis.set(sessionKey, JSON.stringify(sessionData), { EX: SESSION_TTL_SEC });
      
      // Also store a separate active session marker for better tracking
      await redis.set(activeKey, JSON.stringify({
        username,
        serverId,
        lastHeartbeat: now,
        status: 'active'
      }), { EX: SESSION_TTL_SEC });

      // Add to server's active sessions
      await redis.sAdd(serverKey, sessionKey);

      // Send Teams notification for NEW sessions only (debounced by checking recent login time)
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
    
    const now = new Date();
    console.log(`Status check at ${now.toLocaleString('en-US', { timeZone: 'America/Chicago' })} CDT / ${now.toISOString()} UTC / ${now.toString()} Local`);
    
    const redis = await getRedisClient();
    
    try {
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
          scope: 'server',
          serverId,
          activeSessions,
          totalSessions: activeSessions.length
        });
      } else {
        // Return all servers with their active sessions
        const serverKeys = await redis.keys('server:*');
        const servers = [];
        for (const key of serverKeys) {
          const id = key.replace('server:', '');
          const sessionKeys = await redis.sMembers(key);
          const activeSessions = [];
          for (const sessionKey of sessionKeys) {
            const sessionData = await redis.get(sessionKey);
            if (sessionData) {
              activeSessions.push(JSON.parse(sessionData));
            }
          }
          servers.push({ serverId: id, activeSessions, totalSessions: activeSessions.length });
        }
        res.status(200).json({
          scope: 'all',
          servers,
          totalServers: servers.length,
          totalSessions: servers.reduce((sum, s) => sum + s.totalSessions, 0)
        });
      }
    } catch (redisError) {
      console.error('Redis error in status:', redisError);
      res.status(200).json({
        scope: serverId ? 'server' : 'all',
        servers: serverId ? undefined : [],
        serverId: serverId || undefined,
        activeSessions: serverId ? [] : undefined,
        totalServers: serverId ? undefined : 0,
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
  const timeout = LOGOUT_TIMEOUT_SEC * 1000;

  console.log(`Checking for logouts at ${new Date().toLocaleString()}`);

  try {
    // Get all active session markers first
    const activeKeys = await redis.keys('active:*');
    let loggedOffUsers = [];
    let serverIds = new Set();

    // Check active sessions for timeouts
    for (const activeKey of activeKeys) {
      const activeData = await redis.get(activeKey);
      
      if (activeData) {
        const active = JSON.parse(activeData);
        const timeSinceLastHeartbeat = now - active.lastHeartbeat;
        
        console.log(`Checking active session: ${active.username} on ${active.serverId} - ${timeSinceLastHeartbeat}ms since last heartbeat`);
        
        if (timeSinceLastHeartbeat > timeout) {
          // Session timed out - user logged off
          console.log(`Active session timed out: ${active.username} on ${active.serverId} (${timeSinceLastHeartbeat}ms since last heartbeat)`);
          
          // Get the full session data
          const sessionKey = `session:${active.serverId}-${active.username}`;
          const sessionData = await redis.get(sessionKey);
          
          if (sessionData) {
            const session = JSON.parse(sessionData);
            loggedOffUsers.push(session);
            serverIds.add(session.serverId);
            
            // Remove session from storage
            await redis.del(sessionKey);
            await redis.del(activeKey);
            await redis.sRem(`server:${active.serverId}`, sessionKey);
            
                         // Don't send logout notification here - it will be sent as combined message if server becomes free
             console.log(`Logout detected for: ${active.username} on ${active.serverId}`);
          } else {
            // Clean up orphaned active key
            await redis.del(activeKey);
            console.log(`Cleaned up orphaned active key: ${activeKey}`);
          }
        }
      } else {
        // Clean up orphaned active key
        await redis.del(activeKey);
        console.log(`Cleaned up orphaned active key: ${activeKey}`);
      }
    }

    // Also check server sessions for consistency and detect orphaned sessions
    const serverKeys = await redis.keys('server:*');
    for (const serverKey of serverKeys) {
      const sessionKeys = await redis.sMembers(serverKey);
      
      for (const sessionKey of sessionKeys) {
        const sessionData = await redis.get(sessionKey);
        
        if (!sessionData) {
          // Session doesn't exist - this means user was logged off abruptly
          console.log(`Found orphaned session key: ${sessionKey}`);
          
          // Extract username and serverId from session key
          const keyParts = sessionKey.replace('session:', '').split('-');
          if (keyParts.length >= 2) {
            const serverId = keyParts[0];
            const username = keyParts.slice(1).join('-'); // Handle usernames with hyphens
            
            console.log(`Detected abrupt logout for user: ${username} on server: ${serverId}`);
            
                         // Don't send logout notification here - it will be sent as combined message if server becomes free
             console.log(`Abrupt logout detected for: ${username} on ${serverId}`);
            
            loggedOffUsers.push({
              username: username,
              serverId: serverId,
              reason: 'abrupt_disconnection'
            });
            serverIds.add(serverId);
          }
          
          // Remove from server
          await redis.sRem(serverKey, sessionKey);
        }
      }
    }

    console.log(`Logged off users: ${loggedOffUsers.length}`);

    // Check if any servers are now free and send combined messages
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
        // Server is now free - check if we should send combined message
        const chicagoTime = new Date().toLocaleString('en-US', { 
          timeZone: 'America/Chicago',
          year: 'numeric',
          month: '2-digit',
          day: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
          second: '2-digit',
          hour12: false
        });
        
        // Find the user who just logged out from this server
        const loggedOutUser = loggedOffUsers.find(user => user.serverId === serverId);
        
                 if (loggedOutUser) {
           // Send combined logout and server free message
           console.log(`Server ${serverId} is now free after ${loggedOutUser.username} logged out`);
           const sessionDuration = loggedOutUser.sessionDuration || Math.floor((Date.now() - (loggedOutUser.loginTime || Date.now())) / 1000);
           sendTeamsNotification(createCombinedLogoutAndFreeMessage(
             loggedOutUser.username, 
             serverId, 
             loggedOutUser.reason || 'timeout',
             chicagoTime,
             sessionDuration
           ));
           console.log(`Combined logout & server free notification sent for: ${loggedOutUser.username} on ${serverId}`);
         } else {
          // Send regular server free message
          console.log(`Server ${serverId} is now free`);
          sendTeamsNotification(createServerFreeMessage(serverId));
          console.log(`Server free notification sent for: ${serverId}`);
        }
      }
    }

  } catch (error) {
    console.error('Error checking for logouts:', error);
  }
}

async function handleCheckLogouts(req, res) {
  try {
    console.log('Manual logout check requested at', new Date().toLocaleString());
    
    const redis = await getRedisClient();
    
    try {
      await checkForLogouts(redis);
      
      res.status(200).json({ 
        success: true, 
        message: 'Logout check completed',
        timestamp: new Date().toISOString()
      });
      
    } catch (redisError) {
      console.error('Redis error in logout check:', redisError);
      res.status(500).json({ error: 'Redis error during logout check' });
    } finally {
      await redis.disconnect();
    }
    
  } catch (error) {
    console.error('Logout check error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

// Note: Auto logout check removed because Vercel serverless functions don't support background processes
// The client-side script now triggers logout checks every 3 heartbeats instead

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
  const chicagoTime = new Date().toLocaleString('en-US', { 
    timeZone: 'America/Chicago',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
  
  return {
    "text": `🟢 **${username} logged in**\n**Server:** ${serverId}\n**Time:** ${chicagoTime} CDT`
  };
}

function createLogoutMessage(username, serverId, reason = 'manual', sessionDuration = null) {
  const chicagoTime = new Date().toLocaleString('en-US', { 
    timeZone: 'America/Chicago',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
  
  const reasonText = {
    'manual': 'Manual logout',
    'graceful_shutdown': 'Graceful shutdown',
    'timeout': 'Session timeout',
    'abrupt_disconnection': 'Abrupt disconnection',
    'test': 'Test logout'
  };
  
  let durationText = '';
  if (sessionDuration && sessionDuration > 0) {
    const hours = Math.floor(sessionDuration / 3600);
    const minutes = Math.floor((sessionDuration % 3600) / 60);
    const seconds = sessionDuration % 60;
    
    if (hours > 0) {
      durationText = `\n**Session Duration:** ${hours}h ${minutes}m ${seconds}s`;
    } else if (minutes > 0) {
      durationText = `\n**Session Duration:** ${minutes}m ${seconds}s`;
    } else {
      durationText = `\n**Session Duration:** ${seconds}s`;
    }
  }
  
  return {
    "text": `🔴 **${username} logged out**\n**Server:** ${serverId}\n**Time:** ${chicagoTime} CDT\n**Reason:** ${reasonText[reason] || reason}${durationText}`
  };
}

function createServerFreeMessage(serverId) {
  const chicagoTime = new Date().toLocaleString('en-US', { 
    timeZone: 'America/Chicago',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
  
  return {
    "text": `🟢 **Server ${serverId} is available**\n**Time:** ${chicagoTime} CDT\n**Status:** Ready for use`
  };
}

function createCombinedLogoutAndFreeMessage(username, serverId, reason, chicagoTime, sessionDuration = null) {
  const reasonText = {
    'manual': 'Manual logout',
    'graceful_shutdown': 'Graceful shutdown',
    'timeout': 'Session timeout',
    'abrupt_disconnection': 'Abrupt disconnection',
    'test': 'Test logout'
  };
  
  let durationText = '';
  if (sessionDuration && sessionDuration > 0) {
    const hours = Math.floor(sessionDuration / 3600);
    const minutes = Math.floor((sessionDuration % 3600) / 60);
    const seconds = sessionDuration % 60;
    
    if (hours > 0) {
      durationText = `\n**Session Duration:** ${hours}h ${minutes}m ${seconds}s`;
    } else if (minutes > 0) {
      durationText = `\n**Session Duration:** ${minutes}m ${seconds}s`;
    } else {
      durationText = `\n**Session Duration:** ${seconds}s`;
    }
  }
  
  return {
    "text": `🔴 **${username} logged out**\n**Server:** ${serverId}\n**Time:** ${chicagoTime} CDT\n**Reason:** ${reasonText[reason] || reason}${durationText}\n**Status:** Server is now available`
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