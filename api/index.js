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
    await handleHeartbeat(req, res);
  } else if (req.method === 'GET') {
    await handleStatus(req, res);
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

async function handleHeartbeat(req, res) {
  try {
    const { serverId, username, cpu, memory, status, timestamp } = req.body;

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

      // Update heartbeat
      await redis.set(sessionKey, JSON.stringify({
        serverId,
        username,
        loginTime: now,
        lastHeartbeat: now,
        status: status || 'active',
        cpu: cpu,
        memory: memory
      }), { EX: 300 }); // Expire after 5 minutes

      // Add to server's active sessions
      await redis.sadd(serverKey, sessionKey);

      // Check if this is a new session
      const existingSession = await redis.get(sessionKey);
      if (!existingSession) {
        // Send Teams notification for login
        sendTeamsNotification(createLoginMessage(username, serverId));
        console.log(`New session: ${username} on ${serverId}`);
      } else {
        console.log(`Updated session: ${username} on ${serverId}`);
      }

      // Get session count
      const sessionCount = await redis.scard(serverKey);
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
        const sessionKeys = await redis.smembers(serverKey);
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
  const timeout = 90 * 1000; // 90 seconds timeout

  console.log(`Checking for logouts at ${new Date().toLocaleString()}`);

  try {
    // Get all server keys
    const serverKeys = await redis.keys('server:*');
    let loggedOffUsers = [];
    let serverIds = new Set();

    for (const serverKey of serverKeys) {
      const sessionKeys = await redis.smembers(serverKey);
      
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
            await redis.srem(serverKey, sessionKey);
            
            // Send Teams notification for logout
            sendTeamsNotification(createLogoutMessage(session.username, session.serverId));
          }
        } else {
          // Session doesn't exist, remove from server
          await redis.srem(serverKey, sessionKey);
        }
      }
    }

    console.log(`Logged off users: ${loggedOffUsers.length}`);

    // Check if any servers are now free
    for (const serverId of serverIds) {
      const serverKey = `server:${serverId}`;
      const sessionKeys = await redis.smembers(serverKey);
      let serverHasUsers = false;

      for (const sessionKey of sessionKeys) {
        const sessionData = await redis.get(sessionKey);
        if (sessionData) {
          serverHasUsers = true;
          break;
        }
      }
      
      if (!serverHasUsers) {
        // Server is now free
        console.log(`Server ${serverId} is now free`);
        sendTeamsNotification(createServerFreeMessage(serverId));
      }
    }

  } catch (error) {
    console.error('Error checking for logouts:', error);
  }
}

function createLoginMessage(username, serverId) {
  return {
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "00FF00",
    "summary": `🟢 ${username} logged into ${serverId}`,
    "sections": [
      {
        "activityTitle": `🟢 ${username} logged into ${serverId}`,
        "activitySubtitle": `${new Date().toLocaleString()}`,
        "text": `User ${username} is now using server ${serverId}`
      }
    ]
  };
}

function createLogoutMessage(username, serverId) {
  return {
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "FF0000",
    "summary": `🔴 ${username} logged off from ${serverId}`,
    "sections": [
      {
        "activityTitle": `🔴 ${username} logged off from ${serverId}`,
        "activitySubtitle": `${new Date().toLocaleString()}`,
        "text": `User ${username} is no longer using server ${serverId}`
      }
    ]
  };
}

function createServerFreeMessage(serverId) {
  return {
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "00FF00",
    "summary": `🟢 Server ${serverId} is now FREE`,
    "sections": [
      {
        "activityTitle": `🟢 Server ${serverId} is now FREE`,
        "activitySubtitle": `${new Date().toLocaleString()}`,
        "text": `Server ${serverId} is available for use. No users are currently logged in.`
      }
    ]
  };
}

function sendTeamsNotification(message) {
  const webhookUrl = process.env.TEAMS_WEBHOOK_URL;
  
  if (!webhookUrl) {
    console.log('Teams notification (no webhook configured):', message.summary);
    return;
  }

  console.log('Sending Teams notification:', message.summary);

  fetch(webhookUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(message)
  }).then(response => {
    if (!response.ok) {
      console.error('Teams notification failed:', response.status, response.statusText);
    } else {
      console.log('Teams notification sent successfully:', message.summary);
    }
  }).catch(error => {
    console.error('Teams notification error:', error);
  });
} 