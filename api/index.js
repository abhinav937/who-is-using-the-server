// Vercel API for server monitoring
export default function handler(req, res) {
  // Enable CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method === 'POST') {
    handleHeartbeat(req, res);
  } else if (req.method === 'GET') {
    handleStatus(req, res);
  } else {
    res.status(405).json({ error: 'Method not allowed' });
  }
}

// In-memory storage (in production, use a database)
let sessions = new Map();
let lastHeartbeats = new Map();

function handleHeartbeat(req, res) {
  try {
    const { serverId, username, cpu, memory, status, timestamp } = req.body;

    if (!serverId || !username) {
      return res.status(400).json({ error: 'Missing serverId or username' });
    }

    const now = Date.now();
    const sessionKey = `${serverId}-${username}`;

    // Update heartbeat
    lastHeartbeats.set(sessionKey, now);

    // Check if this is a new session
    if (!sessions.has(sessionKey)) {
      sessions.set(sessionKey, {
        serverId,
        username,
        loginTime: now,
        lastHeartbeat: now,
        status: status || 'active'
      });

      // Send Teams notification for login
      sendTeamsNotification(`[LOGIN] **${username}** logged into server **${serverId}**`);
      
      console.log(`New session: ${username} on ${serverId}`);
    } else {
      // Update existing session
      const session = sessions.get(sessionKey);
      session.lastHeartbeat = now;
      session.status = status || 'active';
    }

    res.status(200).json({ 
      success: true, 
      message: 'Heartbeat received',
      sessionCount: sessions.size
    });

  } catch (error) {
    console.error('Heartbeat error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

function handleStatus(req, res) {
  try {
    const { serverId } = req.query;
    const now = Date.now();
    const timeout = 90 * 1000; // 90 seconds timeout

    // Clean up old sessions
    const activeSessions = [];
    const loggedOffUsers = [];

    for (const [sessionKey, session] of sessions.entries()) {
      if (now - session.lastHeartbeat > timeout) {
        // Session timed out - user logged off
        loggedOffUsers.push(session.username);
        sessions.delete(sessionKey);
        lastHeartbeats.delete(sessionKey);
        
        // Send Teams notification for logout
        sendTeamsNotification(`[LOGOFF] **${session.username}** logged off from server **${session.serverId}**`);
      } else if (!serverId || session.serverId === serverId) {
        activeSessions.push(session);
      }
    }

    res.status(200).json({
      activeSessions,
      loggedOffUsers,
      totalSessions: sessions.size
    });

  } catch (error) {
    console.error('Status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}

function sendTeamsNotification(message) {
  const webhookUrl = process.env.TEAMS_WEBHOOK_URL;
  
  if (!webhookUrl) {
    console.log('Teams notification (no webhook configured):', message);
    return;
  }

  const payload = {
    text: message
  };

  fetch(webhookUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload)
  }).then(response => {
    if (!response.ok) {
      console.error('Teams notification failed:', response.status, response.statusText);
    } else {
      console.log('Teams notification sent successfully');
    }
  }).catch(error => {
    console.error('Teams notification error:', error);
  });
} 