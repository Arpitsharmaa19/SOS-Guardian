const express = require('express');
require('dotenv').config();
const bodyParser = require('body-parser');
const twilio = require('twilio');
const cors = require('cors');
const nodemailer = require('nodemailer');

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Global Request Logger
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
    next();
});

// Log environment status on startup
console.log('ENVIRONMENT CHECK:');
console.log('PORT:', process.env.PORT);
console.log('TWILIO_ACCOUNT_SID:', process.env.TWILIO_ACCOUNT_SID ? 'EXISTS' : 'MISSING');
console.log('TWILIO_AUTH_TOKEN:', process.env.TWILIO_AUTH_TOKEN ? 'EXISTS' : 'MISSING');
console.log('TWILIO_PHONE_NUMBER:', process.env.TWILIO_PHONE_NUMBER);
console.log('EMAIL_USER:', process.env.EMAIL_USER ? 'EXISTS' : 'MISSING');

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const voiceNumber = process.env.TWILIO_PHONE_NUMBER;
const whatsappNumber = process.env.TWILIO_WHATSAPP_NUMBER || `whatsapp:${voiceNumber}`;

let client;
if (accountSid && authToken && accountSid.startsWith('AC')) {
    client = twilio(accountSid, authToken);
    console.log('✅ Twilio Client Initialized');
} else {
    console.warn('⚠️ Twilio Credentials missing or invalid in .env!');
}

// Brevo (Sendinblue) SMTP Transporter - Professional & Robust
const transporter = nodemailer.createTransport({
    host: 'smtp-relay.brevo.com',
    port: 587,
    secure: false, // TLS
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS
    }
});

app.get('/', (req, res) => {
    res.send('<h1>SOS Guardian Backend is Running</h1><p>Visit <a href="/status">/status</a> to check system health.</p>');
});

app.get('/status', (req, res) => {
    res.json({
        status: 'online',
        twilioReady: !!client,
        timestamp: new Date().toISOString()
    });
});

app.post('/send-email', async (req, res) => {
    const { to, subject, message } = req.body;

    console.log(`[Request] Sending Email to: ${to}`);

    const mailOptions = {
        from: process.env.EMAIL_USER,
        to: to,
        subject: subject || '🚨 SOS EMERGENCY ALERT 🚨',
        text: message
    };

    try {
        await transporter.sendMail(mailOptions);
        console.log(`✅ EMAIL SUCCESS Sent to: ${to}`);
        res.status(200).json({ success: true });
    } catch (error) {
        console.error(`❌ EMAIL ERROR: ${error.message}`);
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/make-call', async (req, res) => {
    const { to, message } = req.body;

    if (!client) {
        console.error('❌ Twilio NOT READY.');
        return res.status(500).json({ success: false, error: 'Twilio Client not initialized' });
    }

    let cleanTo = to.trim().replace(/\s+/g, '').replace(/-/g, '');
    if (!cleanTo.startsWith('+')) {
        if (cleanTo.length === 10) {
            cleanTo = '+91' + cleanTo;
        } else {
            cleanTo = '+' + cleanTo;
        }
    }

    // Extract the numeric part (remove 'whatsapp:' prefix if accidentally present)
    const fromNumber = voiceNumber.replace('whatsapp:', '');

    console.log(`[Request] Initiating Call to: ${cleanTo} from ${fromNumber}`);

    try {
        const call = await client.calls.create({
            twiml: `<Response><Say voice="Polly.Joanna"><prosody rate="1.15">${message}</prosody></Say></Response>`,
            to: cleanTo,
            from: fromNumber
        });
        console.log(`✅ CALL SUCCESS SID: ${call.sid}`);
        res.status(200).json({ success: true, sid: call.sid });
    } catch (error) {
        console.error(`❌ TWILIO CALL ERROR: ${error.message}`);
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/send-sms', async (req, res) => {
    const { to, message } = req.body;

    if (!client) {
        return res.status(500).json({ success: false, error: 'Twilio Client not initialized' });
    }

    let cleanTo = to.trim().replace(/\s+/g, '').replace(/-/g, '');
    if (!cleanTo.startsWith('+')) {
        cleanTo = (cleanTo.length === 10) ? '+91' + cleanTo : '+' + cleanTo;
    }

    console.log(`[Request] Sending SMS to: ${cleanTo}`);

    try {
        // --- High-Reliability Dual Dispatch (SMS + WhatsApp) ---
        
        // 1. Regular SMS (Good as a backup)
        const sms = await client.messages.create({
            body: message,
            to: cleanTo,
            from: voiceNumber
        });
        console.log(`✅ SMS SUCCESS SID: ${sms.sid}`);

        // 2. WhatsApp Message (Most reliable for India)
        const whatsapp = await client.messages.create({
            body: message,
            from: whatsappNumber, 
            to: `whatsapp:${cleanTo}`
        });
        console.log(`✅ WHATSAPP SUCCESS SID: ${whatsapp.sid}`);

        res.status(200).json({ success: true, smsSid: sms.sid, waSid: whatsapp.sid });
    } catch (error) {
        console.error(`❌ DISPATCH ERROR: ${error.message}`);
        res.status(500).json({ success: false, error: error.message });
    }
});

// --- RULE-FREE EMERGENCY COMMAND CENTER ---
let activeEmergencyRegistry = {}; // Simple In-Memory DB

// 1. Victim Endpoint: Broadcast Signal to HQ
app.post('/report-sos', (req, res) => {
    const { userId, userName, userPhone, userEmail, userAddress, userBlood, userPhoto, emotion, lat, lng, locationLink } = req.body;
    
    if (!userId) return res.status(400).json({ error: 'Missing Identity' });

    console.log(`📡 HQ SIGNAL: SOS recieved from ${userName} (${userPhone})`);
    
    activeEmergencyRegistry[userId] = {
        userId,
        userName,
        userPhone,
        userEmail,
        userAddress,
        userBlood,
        userPhoto,
        emotion,
        lat: parseFloat(lat),
        lng: parseFloat(lng),
        locationLink,
        timestamp: new Date().toISOString(),
        status: 'active'
    };

    res.status(200).json({ success: true, message: 'HQ Notified' });
});

// 2. Police Endpoint: Fetch All Active Emergencies
app.get('/hq-dashboard', (req, res) => {
    // Return only active cases
    const activeCases = Object.values(activeEmergencyRegistry).filter(c => c.status === 'active');
    res.json({ emergencies: activeCases });
});

// 3. Police Endpoint: Resolve Case
app.post('/hq-resolve', (req, res) => {
    const { userId } = req.body;
    if (activeEmergencyRegistry[userId]) {
        activeEmergencyRegistry[userId].status = 'resolved';
        console.log(`✅ HQ RESOLVE: Case for ${userId} closed.`);
    }
    res.json({ success: true });
});

// 4. Police Endpoint: Fetch Resolved History
app.get('/hq-history', (req, res) => {
    // Return only resolved cases, sorted by latest first
    const resolvedCases = Object.values(activeEmergencyRegistry)
        .filter(c => c.status === 'resolved')
        .sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));
    res.json({ history: resolvedCases });
});

app.post('/analyze-emotion', async (req, res) => {
    console.log(`[Alert Debug] Full Request Body:`, JSON.stringify(req.body));
    const { message, codeword, soundLevel } = req.body;
    const msg = (message || '').toLowerCase();
    const volume = parseFloat(soundLevel) || 0;

    console.log(`[Situation AI] Analyzing: "${msg}" | volume: ${volume}dB`);

    let emotion = 'Urgent Alert';
    let urgency = 'High';

    // SITUATIONAL KEYWORD CATEGORIES
    const PANIC_KEYWORDS = ['please', 'scared', 'terror', 'running', 'emergency', 'somebody', 'anyone', 'hide'];
    const ANGER_KEYWORDS = ['stop', 'dont', 'go away', 'get off', 'back off', 'hey', 'leave', 'fighting'];
    const MEDICAL_KEYWORDS = ['pain', 'hurt', 'heart', 'blood', 'doctor', 'ambulance', 'falling', 'faint', 'chest'];
    const STEALTH_KEYWORDS = ['shh', 'quiet', 'bathroom', 'closet', 'dark'];

    // 1. Priority Text Analysis (What is actually happening?)
    if (PANIC_KEYWORDS.some(k => msg.includes(k))) {
        emotion = 'Panic / Terror (High Distress)';
        urgency = 'Critical';
    } else if (ANGER_KEYWORDS.some(k => msg.includes(k))) {
        emotion = 'Anger / Conflict (Physical Threat)';
        urgency = 'Extreme';
    } else if (MEDICAL_KEYWORDS.some(k => msg.includes(k))) {
        emotion = 'Medical Emergency / Physical Pain';
        urgency = 'High';
    } else if (STEALTH_KEYWORDS.some(k => msg.includes(k)) || (volume < 40 && volume > 0)) {
        emotion = 'Quiet / Stealth SOS (User Hiding)';
        urgency = 'High (Tactical)';
    } else if (volume > 75) {
        emotion = 'Aggressive Distress (High Volume)';
        urgency = 'High';
    }

    console.log(`✅ ANALYSIS COMPLETE: Situation -> ${emotion}`);
    
    res.status(200).json({
        success: true,
        emotion: emotion,
        urgency: urgency,
        confidence: 0.95
    });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`SOS Backend listening on port ${PORT}`);
});
