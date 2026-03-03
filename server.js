const express = require('express');
const bodyParser = require('body-parser');
const twilio = require('twilio');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(bodyParser.json());

// Twiilo Credentials (Set these on Render Dashboard)
const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const twilioNumber = process.env.TWILIO_PHONE_NUMBER; // Use WhatsApp number format like 'whatsapp:+14155238886'

const client = twilio(accountSid, authToken);

app.post('/send-whatsapp', async (req, res) => {
    const { to, message } = req.body;

    try {
        const response = await client.messages.create({
            body: message,
            from: twilioNumber, // Must be your Twilio WhatsApp Sandbox number
            to: `whatsapp:${to}`
        });
        console.log('WhatsApp message sent:', response.sid);
        res.status(200).json({ success: true, sid: response.sid });
    } catch (error) {
        console.error('Error sending WhatsApp:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`SOS Backend running on port ${PORT}`);
});
