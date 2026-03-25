const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const twilio = require('twilio');
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

// --- MONGODB CONNECTION (Atlas) ---
const MONGODB_URI = process.env.MONGODB_URI;
mongoose.connect(MONGODB_URI)
    .then(() => console.log('✅ DATABASE: Pure MongoDB Protection Mode active'))
    .catch(err => console.error('❌ MONGODB ERROR:', err));

// --- SCHEMAS ---
const UserSchema = new mongoose.Schema({
    userId: { type: String, unique: true, required: true },
    name: String,
    email: { type: String, unique: true, required: true },
    password: { type: String, required: true }, 
    phone: String,
    address: String,
    bloodType: String,
    photoUrl: String, // Store as Base64 for simplicity
    codeword: { type: String, default: 'help me' },
    contactList: { type: Map, of: String } // Key: Relation/Name, Value: Phone
});
const User = mongoose.model('User', UserSchema);

const ReportSchema = new mongoose.Schema({
    reportId: { type: String, unique: true, required: true },
    userId: String,
    userName: String,
    userPhone: String,
    userAddress: String,
    userBlood: String,
    userPhoto: String,
    emotion: String, // This will store our detected situation
    lat: Number,
    lng: Number,
    locationLink: String,
    status: { type: String, default: 'active' },
    timestamp: { type: Date, default: Date.now },
    resolvedAt: Date
});
const SOSReport = mongoose.model('SOSReport', ReportSchema);

// --- TWILIO INITIALIZATION ---
const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;
const voiceNumber = process.env.TWILIO_PHONE_NUMBER;
const whatsappNumber = process.env.TWILIO_WHATSAPP_NUMBER || `whatsapp:${voiceNumber}`;

let client;
if (accountSid && authToken && accountSid.startsWith('AC')) {
    client = twilio(accountSid, authToken);
}

// --- CORE AUTH APIS (REPLACING FIREBASE) ---

app.post('/register', async (req, res) => {
    console.log(`[AUTH] Registration request for: ${req.body.email}`);
    try {
        const userId = `U-${Date.now()}`;
        const newUser = new User({ ...req.body, userId });
        await newUser.save();
        res.status(200).json({ success: true, userId: userId, user: newUser });
    } catch (err) {
        console.error("Reg Error:", err.message);
        res.status(500).json({ success: false, error: "Registration failed: " + err.message });
    }
});

app.post('/login', async (req, res) => {
    const { email, password } = req.body;
    console.log(`[AUTH] Login attempt: ${email}`);
    try {
        const user = await User.findOne({ email, password });
        if (user) {
            res.json({ success: true, userId: user.userId, user: user });
        } else {
            res.status(401).json({ success: false, error: "Invalid credentials" });
        }
    } catch (err) {
        res.status(500).json({ success: false, error: "Login failed" });
    }
});

app.post('/update-codeword', async (req, res) => {
    const { userId, codeword } = req.body;
    try {
        await User.findOneAndUpdate({ userId }, { codeword });
        res.json({ success: true });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// --- THE EMERGENCY ENGINE (WORD-BASED SITUATION AI) ---

app.post('/report-sos', async (req, res) => {
    const { reportId, userId, userName, userPhone, locationLink, message } = req.body;
    
    // 🧠 1. Word Analysis (IGNORE "HELP" TRIGGER)
    const msg = (message || '').toLowerCase();
    let situation = "General Distress Alert"; // Default Case

    // Priority Detection Logic (Heuristics)
    if (msg.includes('pain') || msg.includes('hurt') || msg.includes('doctor') || msg.includes('blood') || msg.includes('ambulance')) {
        situation = "🚨 MEDICAL EMERGENCY (Injury Reported)";
    } else if (msg.includes('stop') || msg.includes('don\'t') || msg.includes('scared') || msg.includes('get off') || msg.includes('fighting') || msg.includes('weapon')) {
        situation = "⚠️ PHYSICAL THREAT / AGGRESSION DETECTED";
    }

    console.log(`📡 HQ SIGNAL: SOS from ${userName} [Situation: ${situation}]`);

    try {
        // 💾 2. Save/Update Report in MongoDB with detected emotion
        const report = await SOSReport.findOneAndUpdate(
            { reportId: reportId || `R-${Date.now()}` },
            { ...req.body, emotion: situation, status: 'active' },
            { upsert: true, new: true }
        );

        // 📡 3. Broadcast to Police Dashboard via Socket.io
        io.emit('new-sos', report);

        // 📱 4. WHATSAPP DISPATCH (Twilio)
        if (userPhone && client) {
            const alertMsg = `🆘 SOS! EMERGENCY DETECTED!
Victim: ${userName.toUpperCase()}
SITUATION: ${situation}
Live Tracking: ${locationLink || 'Unavailable'}`;

            // Send WhatsApp
            client.messages.create({
                body: alertMsg,
                from: whatsappNumber,
                to: `whatsapp:${userPhone}`
            }).catch(e => console.error("WA Dispatch Fail:", e.message));

            // Backup Call
            client.calls.create({
                twiml: `<Response><Say voice="Polly.Joanna">Emergency alert! ${userName} is in a state of ${situation}. Check your WhatsApp for the live location.</Say></Response>`,
                to: userPhone.replace('whatsapp:', ''),
                from: voiceNumber.replace('whatsapp:', '')
            }).catch(e => console.error("Call Dispatch Fail:", e.message));
        }

        res.json({ success: true, reportId: report.reportId, emotion: situation });
    } catch (err) {
        console.error("Save Error:", err.message);
        res.status(500).json({ error: err.message });
    }
});

// --- POLICE COMMAND CENTER BEYOND THE CLOUD ---

app.get('/hq-dashboard', async (req, res) => {
    const active = await SOSReport.find({ status: 'active' }).sort({ timestamp: -1 });
    res.json({ success: true, emergencies: active });
});

app.post('/hq-resolve', async (req, res) => {
    const { reportId } = req.body;
    await SOSReport.findOneAndUpdate({ reportId }, { status: 'resolved', resolvedAt: new Date() });
    io.emit('sos-resolved', reportId);
    res.json({ success: true });
});

app.get('/hq-history', async (req, res) => {
    const history = await SOSReport.find({ status: 'resolved' }).sort({ resolvedAt: -1 }).limit(50);
    res.json({ success: true, history });
});

app.get('/my-history/:userId', async (req, res) => {
    const history = await SOSReport.find({ userId: req.params.userId }).sort({ timestamp: -1 });
    res.json({ success: true, history });
});

app.get('/status', (req, res) => {
    res.json({ status: 'online', twilio: !!client, mongoose: mongoose.connection.readyState === 1 });
});

server.listen(PORT, () => {
    console.log(`///////////////////////////////////////////////////`);
    console.log(`SOS GUARDIAN: MONGO-PURE BACKEND ACTIVE (Port: ${PORT})`);
    console.log(`///////////////////////////////////////////////////`);
});
