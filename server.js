const express = require('express');
require('dotenv').config();
const bodyParser = require('body-parser');
const twilio = require('twilio');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Log environment status on startup
console.log('ENVIRONMENT CHECK:');
console.log('PORT:', process.env.PORT);
console.log('TWILIO_ACCOUNT_SID:', process.env.TWILIO_ACCOUNT_SID ? 'EXISTS' : 'MISSING');
console.log('TWILIO_AUTH_TOKEN:', process.env.TWILIO_AUTH_TOKEN ? 'EXISTS' : 'MISSING');
console.log('TWILIO_PHONE_NUMBER:', process.env.TWILIO_PHONE_NUMBER);

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const twilioNumber = process.env.TWILIO_PHONE_NUMBER;

let client;
if (accountSid && authToken && accountSid.startsWith('AC')) {
    client = twilio(accountSid, authToken);
    console.log('✅ Twilio Client Initialized');
} else {
    console.warn('⚠️ Twilio Credentials missing or invalid in .env!');
}

app.get('/status', (req, res) => {
    res.json({
        status: 'online',
        twilioReady: !!client,
        timestamp: new Date().toISOString()
      });
});

app.post('/analyze-emotion', async (req, res) => {
    const { message, codeword } = req.body;
    const trigger = (codeword || 'help').toLowerCase();
    
    // Remove the trigger word from the text to analyze the *context*
    let msg = (message || '').toLowerCase().replace(trigger, '').trim();

    console.log(`[Situation AI] Analyzing Context: "${msg}"`);

    let emotion = 'General Distress';
    let urgency = 'High';

    // SITUATIONAL KEYWORD CATEGORIES (Speech-Only)
    const MEDICAL = ['pain', 'hurt', 'blood', 'doctor', 'ambulance', 'faint', 'heart', 'breathing', 'injury'];
    const THREAT = ['go away', 'stop', 'dont', 'get off', 'leave', 'fighting', 'weapon', 'gun', 'knife'];
    const PANIC = ['scared', 'terror', 'emergency', 'help me', 'danger'];

    if (MEDICAL.some(k => msg.includes(k))) {
        emotion = 'Medical Emergency';
        urgency = 'Critical';
    } else if (THREAT.some(k => msg.includes(k))) {
        emotion = 'Physical Threat / Assault';
        urgency = 'Extreme';
    } else if (PANIC.some(k => msg.includes(k))) {
        emotion = 'Panic & Distress';
        urgency = 'High';
    }

    console.log(`✅ ANALYSIS COMPLETE: Situation -> ${emotion}`);
    
    res.status(200).json({
        success: true,
        emotion: emotion,
        urgency: urgency
    });
});

app.post('/send-whatsapp', async (req, res) => {
    const { to, message } = req.body;

    let cleanTo = to.trim().replace(/\s+/g, '').replace(/-/g, '');
    if (!cleanTo.startsWith('+')) {
        cleanTo = (cleanTo.length === 10) ? '+91' + cleanTo : '+' + cleanTo;
    }

    const formattedTo = `whatsapp:${cleanTo}`;
    console.log(`[Request] Sending to: ${formattedTo}`);

    if (!client) {
        return res.status(500).json({ success: false, error: 'Twilio Client not initialized' });
    }

    try {
        const response = await client.messages.create({
            body: message,
            from: twilioNumber,
            to: formattedTo
        });
        console.log(`✅ SUCCESS SID: ${response.sid}`);
        res.status(200).json({ success: true, sid: response.sid });
    } catch (error) {
        console.error(`❌ TWILIO ERROR: ${error.message}`);
        res.status(500).json({ success: false, error: error.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
    console.log(`SOS Backend listening on port ${PORT}`);
});
