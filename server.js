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
const DEPLOY_DATE = "2026-04-24 (v2.2 Debug Logs)";
let recentErrors = []; // Track recent Twilio errors for remote debugging

app.use(cors());
app.use(bodyParser.json());

const logError = (msg) => {
    recentErrors.unshift(`[${new Date().toISOString()}] ${msg}`);
    if (recentErrors.length > 5) recentErrors.pop();
};

console.log(`🚀 DEPLOYMENT VERSION: ${DEPLOY_DATE}`);

// Global Request Logger
app.use((req, res, next) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
    next();
});

// Log environment status on startup
console.log('ENVIRONMENT CHECK:');
console.log('PORT:', process.env.PORT);
console.log('TWILIO_ACCOUNT_SID:', process.env.TWILIO_ACCOUNT_SID ? `${process.env.TWILIO_ACCOUNT_SID.substring(0, 4)}...` : 'MISSING');
console.log('TWILIO_AUTH_TOKEN:', process.env.TWILIO_AUTH_TOKEN ? `${process.env.TWILIO_AUTH_TOKEN.substring(0, 4)}...` : 'MISSING');
console.log('TWILIO_PHONE_NUMBER:', process.env.TWILIO_PHONE_NUMBER);
console.log('TWILIO_WHATSAPP_NUMBER:', process.env.TWILIO_WHATSAPP_NUMBER || 'NOT SET (Defaulting to sandbox or voice number)');
console.log('EMAIL_USER:', process.env.EMAIL_USER ? 'EXISTS' : 'MISSING');
console.log('MONGODB_URI:', process.env.MONGODB_URI ? 'EXISTS' : 'MISSING');


const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const voiceNumber = process.env.TWILIO_PHONE_NUMBER;
// Default to Twilio Sandbox number if not provided
const whatsappNumber = process.env.TWILIO_WHATSAPP_NUMBER || 'whatsapp:+14155238886';

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
        version: DEPLOY_DATE,
        twilioReady: !!client,
        whatsappSender: whatsappNumber,
        recentErrors: recentErrors, // Exposed for debugging
        timestamp: new Date().toISOString()
    });
});

// Diagnostic endpoint to check Twilio
app.get('/test-twilio', async (req, res) => {
    if (!client) return res.status(500).json({ error: 'Twilio not initialized' });
    try {
        const account = await client.api.v2010.accounts(accountSid).fetch();
        res.json({ 
            success: true, 
            accountStatus: account.status, 
            type: account.type,
            whatsappSender: whatsappNumber,
            hint: "Ensure you sent 'join <sandbox-keyword>' to " + whatsappNumber.replace('whatsapp:', '')
        });
    } catch (e) {
        res.status(500).json({ success: false, error: e.message });
    }
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

/**
 * Robust Phone Number Cleaner
 * Handles: Spaces, Dashes, Leading Zeros, Missing Country Codes
 */
const cleanPhoneNumber = (number) => {
    if (!number) return null;
    let clean = number.toString().trim().replace(/\s+/g, '').replace(/-/g, '').replace(/\(/g, '').replace(/\)/g, '');
    
    // Handle leading zero (common in some regions)
    if (clean.startsWith('0') && !clean.startsWith('00')) {
        clean = clean.substring(1);
    }

    if (!clean.startsWith('+')) {
        // Default to India if 10 digits
        if (clean.length === 10) {
            clean = '+91' + clean;
        } else {
            clean = '+' + clean;
        }
    }
    return clean;
};

app.post('/make-call', async (req, res) => {
    const { to, message } = req.body;

    if (!client) {
        console.error('❌ Twilio NOT READY.');
        return res.status(500).json({ success: false, error: 'Twilio Client not initialized' });
    }

    const cleanTo = cleanPhoneNumber(to);
    if (!cleanTo) {
        console.error('❌ ERROR: No recipient phone number provided.');
        return res.status(400).json({ success: false, error: 'Recipient phone number is required' });
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
        console.error(`❌ TWILIO CALL ERROR [${error.code}]: ${error.message}`);
        logError(`CALL to ${cleanTo} FAILED [${error.code}]: ${error.message}`);
        let hint = "";
        if (error.code === 21608) hint = "Recipient number is unverified in Twilio Trial Account.";
        if (error.code === 21211) hint = "Invalid 'To' phone number.";
        
        res.status(500).json({ success: false, error: error.message, hint });
    }
});

app.post('/send-sms', async (req, res) => {
    const { to, message } = req.body;

    if (!client) {
        return res.status(500).json({ success: false, error: 'Twilio Client not initialized' });
    }

    const cleanTo = cleanPhoneNumber(to);
    if (!cleanTo) return res.status(400).json({ success: false, error: 'Invalid number' });

    console.log(`[Request] Dispatching Alert to: ${cleanTo} (SMS & WhatsApp)`);

    try {
        let smsSid = 'skipped';
        let waSid = 'skipped';
        let errors = [];

        // 1. Regular SMS Dispatch
        try {
            const sms = await client.messages.create({
                body: message,
                to: cleanTo,
                from: voiceNumber
            });
            smsSid = sms.sid;
            console.log(`✅ SMS SUCCESS SID: ${smsSid}`);
        } catch (smsErr) {
            console.error(`❌ SMS FAILED: ${smsErr.message}`);
            logError(`SMS to ${cleanTo} FAILED: ${smsErr.message}`);
            errors.push(`SMS: ${smsErr.message}`);
        }

        // 2. WhatsApp Dispatch
        try {
            const whatsapp = await client.messages.create({
                body: message,
                from: whatsappNumber, 
                to: `whatsapp:${cleanTo}`
            });
            waSid = whatsapp.sid;
            console.log(`✅ WHATSAPP SUCCESS SID: ${waSid}`);
        } catch (waErr) {
            console.error(`❌ WHATSAPP FAILED [${waErr.code}]: ${waErr.message}`);
            logError(`WA to ${cleanTo} FAILED [${waErr.code}]: ${waErr.message}`);
            let waHint = "";
            if (waErr.code === 63003) waHint = "Recipient has not joined the WhatsApp sandbox.";
            if (waErr.code === 21608) waHint = "Number unverified in Trial account.";
            errors.push(`WhatsApp: ${waErr.message} ${waHint}`);
        }

        res.status(200).json({ 
            success: smsSid !== 'skipped' || waSid !== 'skipped', 
            smsSid, 
            waSid,
            errors: errors.length > 0 ? errors : undefined
        });
    } catch (error) {
        console.error(`❌ DISPATCH CRITICAL ERROR: ${error.message}`);
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

// SITUATIONAL ANALYSIS HELPER (Internal to ensure instant dispatch)
const performAnalysis = (message, codeword) => {
    const trigger = (codeword || 'help').toLowerCase();
    let msg = (message || '').toLowerCase().replace(trigger, '').trim();
    
    let emotion = 'Panic / Terror (High Distress)'; // Default
    let urgency = 'High';

    const MEDICAL = ['pain', 'hurt', 'blood', 'doctor', 'ambulance', 'faint', 'heart', 'breathing', 'injury', 'medical'];
    const ANGER = ['stop', 'dont', 'go away', 'get off', 'leave', 'fighting', 'weapon', 'back off', 'hey', 'shut up'];
    const PANIC = ['scared', 'terror', 'emergency', 'danger', 'hide', 'running', 'anyone', 'somebody'];

    if (MEDICAL.some(k => msg.includes(k))) {
        emotion = 'Medical Emergency / Physical Pain';
        urgency = 'Extreme';
    } else if (ANGER.some(k => msg.includes(k))) {
        emotion = 'Anger / Conflict (Physical Threat)';
        urgency = 'Extreme';
    } else if (PANIC.some(k => msg.includes(k))) {
        emotion = 'Panic / Terror (High Distress)';
        urgency = 'High';
    }
    return { emotion, urgency };
};

// 1. Victim Endpoint: Broadcast Signal to HQ
app.post('/report-sos', async (req, res) => {
    const { 
        reportId, userId, userName, userPhone, userEmail, 
        userAddress, userBlood, userPhoto, message, 
        codeword, lat, lng, locationLink, contacts 
    } = req.body;
    
    const rid = reportId || `R-${Date.now()}`;
    if (!rid) return res.status(400).json({ error: 'Missing Identity' });

    console.log(`📡 HQ SIGNAL: SOS received from ${userName} [Report ID: ${rid}]`);
    
    // PERFORM IMMEDIATE ANALYSIS UPON RECEIPT
    const analysis = performAnalysis(message, codeword);
    const finalEmotion = analysis.emotion;

    // Build a reliable location link if none provided but coords exist
    const finalLocationLink = locationLink && locationLink !== 'Unknown' 
        ? locationLink 
        : (lat && lng ? `https://www.google.com/maps/search/?api=1&query=${lat},${lng}` : 'Location Unavailable');

    try {
        const report = await SOSReport.findOneAndUpdate(
            { reportId: rid },
            { 
                reportId: rid, userId, userName, userPhone, userEmail, userAddress, userBlood, userPhoto, 
                emotion: finalEmotion, 
                lat, lng, locationLink: finalLocationLink,
                status: 'active' 
            },
            { upsert: true, new: true }
        );

        // Broadcast to Dashboard via Socket.io
        io.emit('new-sos', report);

        // --- DISPATCH ALERTS (Twilio/WhatsApp/Email) ---
        const victimName = (userName || 'A Citizen').toUpperCase();
        const alertMsg = `🚨 SOS EMERGENCY ALERT 🚨
        
Victim: ${victimName}
Situation: ${finalEmotion}
Context: ${message || 'Voice Triggered'}

📍 LIVE LOCATION:
${finalLocationLink}`;

        // 1. Alert Emergency Contacts (If provided in payload)
        if (contacts && Array.isArray(contacts) && client) {
            console.log(`📱 Dispatching alerts to ${contacts.length} contacts...`);
            for (const contact of contacts) {
                const targetPhone = cleanPhoneNumber(contact.phone || contact);
                if (!targetPhone) continue;

                // SMS Dispatch
                client.messages.create({ body: alertMsg, to: targetPhone, from: voiceNumber })
                    .then(m => console.log(`✅ SMS Sent to ${targetPhone}`))
                    .catch(e => {
                        console.error(`❌ SMS FAILED for ${targetPhone}: ${e.message}`);
                        logError(`SMS to ${targetPhone} FAILED: ${e.message}`);
                    });

                // WhatsApp Dispatch
                client.messages.create({ body: alertMsg, from: whatsappNumber, to: `whatsapp:${targetPhone}` })
                    .then(m => console.log(`✅ WhatsApp Sent to ${targetPhone}`))
                    .catch(e => {
                        console.error(`❌ WA FAILED for ${targetPhone}: ${e.message}`);
                        logError(`WA to ${targetPhone} FAILED: ${e.message}`);
                    });
            }
        }

        // 2. Alert Priority (Police/Guardian Email)
        if (userEmail) {
            transporter.sendMail({ from: process.env.EMAIL_USER, to: userEmail, subject: `🚨 SOS EMERGENCY: ${finalEmotion} 🚨`, text: alertMsg })
                .catch(e => console.error("Alert Email fail:", e.message));
        }

        // 3. Optional: Tactical Call to Victim (Can be disabled if annoying)
        if (userPhone && client) {
            const victimCleanPhone = cleanPhoneNumber(userPhone);
            client.calls.create({
                twiml: `<Response><Say voice="Polly.Joanna">Emergency alert triggered. Dispatching help to your location. Stay on the line if possible.</Say></Response>`,
                to: victimCleanPhone,
                from: voiceNumber.replace('whatsapp:', '')
            }).catch(e => console.error("Victim Call fail:", e.message));
        }

        res.json({ success: true, reportId: rid, emotion: finalEmotion, location: finalLocationLink });
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
    const { message, codeword } = req.body;
    const trigger = (codeword || 'help').toLowerCase();
    
    // Remove the trigger word from the text to analyze the *context*
    let msg = (message || '').toLowerCase().replace(trigger, '').trim();

    console.log(`[Situation AI] Analyzing Context: "${msg}"`);

    let emotion = 'Panic / Terror (High Distress)'; // Default
    let urgency = 'High';

    // SITUATIONAL KEYWORD CATEGORIES (Speech-Only, Exclude trigger word)
    const MEDICAL = ['pain', 'hurt', 'blood', 'doctor', 'ambulance', 'faint', 'heart', 'breathing', 'injury', 'medical'];
    const ANGER = ['stop', 'dont', 'go away', 'get off', 'leave', 'fighting', 'weapon', 'back off', 'hey', 'shut up'];
    const PANIC = ['scared', 'terror', 'emergency', 'danger', 'hide', 'running', 'anyone', 'somebody'];

    if (MEDICAL.some(k => msg.includes(k))) {
        emotion = 'Medical Emergency / Physical Pain';
        urgency = 'Extreme';
    } else if (ANGER.some(k => msg.includes(k))) {
        emotion = 'Anger / Conflict (Physical Threat)';
        urgency = 'Extreme';
    } else if (PANIC.some(k => msg.includes(k))) {
        emotion = 'Panic / Terror (High Distress)';
        urgency = 'High';
    }

    console.log(`✅ ANALYSIS COMPLETE: Situation -> ${emotion}`);
    
    res.status(200).json({
        success: true,
        emotion: emotion,
        urgency: urgency
    });
});

// --- SERVER START ---
server.listen(PORT, () => {
    console.log(`///////////////////////////////////////////////////`);
    console.log(`SOS GUARDIAN COMMAND CENTER (${DEPLOY_DATE})`);
    console.log(`Listening on Port: ${PORT}`);
    console.log(`Available at: http://localhost:${PORT}`);
    console.log(`///////////////////////////////////////////////////`);
});
