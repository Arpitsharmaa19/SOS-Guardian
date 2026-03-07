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

app.post('/send-whatsapp', async (req, res) => {
    const { to, message } = req.body;

    // Improved formatting for Twilio WhatsApp
    let cleanTo = to.trim().replace(/\s+/g, '').replace(/-/g, '');

    // Add + if missing
    if (!cleanTo.startsWith('+')) {
        // If 10 digits, assume India (+91)
        if (cleanTo.length === 10) {
            cleanTo = '+91' + cleanTo;
        } else {
            cleanTo = '+' + cleanTo;
        }
    }

    const formattedTo = `whatsapp:${cleanTo}`;
    console.log(`[Request] Sending to: ${formattedTo}`);

    if (!client) {
        console.error('❌ Twilio NOT READY. Check .envKeys');
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
