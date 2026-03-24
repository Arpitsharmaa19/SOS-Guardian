const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const twilio = require('twilio');
const nodemailer = require('nodemailer');
const mongoose = require('mongoose');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
const io = new Server(server, { cors: { origin: "*" } });
const PORT = process.env.PORT || 10000;

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
console.log('MONGODB_URI:', process.env.MONGODB_URI ? 'EXISTS' : 'MISSING');


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

// --- DATABASE SETUP (MongoDB Atlas) ---
const MONGODB_URI = process.env.MONGODB_URI;
mongoose.connect(MONGODB_URI)
    .then(() => console.log('✅ MongoDB Connected Ready for SOS signals'))
    .catch(err => console.error('❌ MongoDB Connection Error:', err));

const ReportSchema = new mongoose.Schema({
    reportId: { type: String, unique: true, required: true },
    userId: String,
    userName: String,
    userPhone: String,
    userEmail: String,
    userAddress: String,
    userBlood: String,
    userPhoto: String,
    emotion: String,
    lat: Number,
    lng: Number,
    locationLink: String,
    status: { type: String, default: 'active' },
    timestamp: { type: Date, default: Date.now },
    resolvedAt: Date
});

const SOSReport = mongoose.model('SOSReport', ReportSchema);

// --- RULE-FREE EMERGENCY COMMAND CENTER ---

// 1. Victim Endpoint: Broadcast Signal to HQ
app.post('/report-sos', async (req, res) => {
    const { reportId, userId, userName, userPhone, userEmail, userAddress, userBlood, userPhoto, emotion, lat, lng, locationLink } = req.body;
    
    const rid = reportId || `R-${Date.now()}`;
    if (!rid) return res.status(400).json({ error: 'Missing Identity' });

    console.log(`📡 HQ SIGNAL: SOS recieved from ${userName} [Report ID: ${rid}]`);
    
    try {
        const report = await SOSReport.findOneAndUpdate(
            { reportId: rid },
            { 
                reportId: rid, userId, userName, userPhone, userEmail, userAddress, userBlood, userPhoto, emotion, lat, lng, locationLink,
                status: 'active' 
            },
            { upsert: true, new: true }
        );

        // Broadcast to Dashboard via Socket.io
        io.emit('new-sos', report);

        // --- DISPATCH ALERTS (Twilio/WhatsApp/Email) ---
        // Basic throttle (Send if new activation, or if specifically requested)
        if (!reportId || (report && report.status === 'active')) {
            const victimName = (userName || 'A Citizen').toUpperCase();
            const alertMsg = `🆘 SOS! EMERGENCY DETECTED!
Victim: ${victimName}
Location: ${locationLink || 'Unknown'}
Status: ${emotion || 'Distress Alert'}`;

            // 1. Alert Emergency Contacts (SMS + WhatsApp)
            if (userPhone && client) {
                client.messages.create({ body: alertMsg, to: userPhone, from: voiceNumber })
                    .catch(e => console.error("Alert SMS fail:", e.message));
            }

            // 2. Alert Priority (Police Email)
            if (userEmail) {
                transporter.sendMail({ from: process.env.EMAIL_USER, to: userEmail, subject: `🚨 SOS GUARDIAN ALERT: ${victimName} 🚨`, text: alertMsg })
                    .catch(e => console.error("Alert Email fail:", e.message));
            }

            // 3. Initiate Tactical Call
            if (userPhone && client) {
                client.calls.create({
                    twiml: `<Response><Say voice="Polly.Joanna">Emergency, Emergency. SOS alert from ${victimName}. Please check your command dashboard.</Say></Response>`,
                    to: userPhone,
                    from: voiceNumber.replace('whatsapp:', '')
                }).catch(e => console.error("Alert Call fail:", e.message));
            }
        }

        res.json({ success: true, reportId: rid });
    } catch (err) {
        console.error("Save Error:", err.message);
        res.status(500).json({ error: `Save failed: ${err.message}` });
    }
});

// 2. Police Endpoint: Fetch DashboardData
app.get('/hq-dashboard', async (req, res) => {
    try {
        const active = await SOSReport.find({ status: 'active' }).sort({ timestamp: -1 });
        res.json({ success: true, emergencies: active });
    } catch (err) {
        res.status(500).json({ error: `Fetch failed: ${err.message}` });
    }
});

// 3. Police Endpoint: Resolve Case
app.post('/hq-resolve', async (req, res) => {
    const { reportId } = req.body;
    try {
        await SOSReport.findOneAndUpdate(
            { reportId: reportId },
            { status: 'resolved', resolvedAt: new Date() }
        );
        console.log(`✅ HQ RESOLVE: Case for ${reportId} closed.`);
        io.emit('sos-resolved', reportId);
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: "Resolve failed" });
    }
});

// 4. Archive: Fetch Resolved History
app.get('/hq-history', async (req, res) => {
    try {
        const history = await SOSReport.find({ status: 'resolved' }).sort({ resolvedAt: -1 }).limit(100);
        res.json({ success: true, history: history });
    } catch (err) {
        res.status(500).json({ error: "History fetch failed" });
    }
});

// 5. Citizen: Personal History
app.get('/my-history/:userId', async (req, res) => {
    try {
        const history = await SOSReport.find({ 
            userId: req.params.userId,
            status: { $ne: 'archived_by_user' }
        }).sort({ timestamp: -1 });
        res.json({ success: true, history: history });
    } catch (err) {
        res.status(500).json({ error: "Personal history failed" });
    }
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
    });
});

// --- SERVER START ---
server.listen(PORT, () => {
    console.log(`///////////////////////////////////////////////////`);
    console.log(`SOS GUARDIAN COMMAND CENTER (v2.0 Persistence)`);
    console.log(`Listening on Port: ${PORT}`);
    console.log(`Available at: http://localhost:${PORT}`);
    console.log(`///////////////////////////////////////////////////`);
});
