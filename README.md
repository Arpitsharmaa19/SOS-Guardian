# 🔊 Voice-Activated SOS App (VoiceAid)

A Flutter-based personal safety app that empowers users to call for help using just their voice.

## 🚨 Overview

The **Voice-Activated SOS App** is designed to provide quick and discreet emergency assistance. With a user-defined codeword, the app instantly sends an SOS message to designated emergency contacts—no need to touch your device.

## ✨ Features

- 🔐 **Voice Triggered SOS**: Speak a predefined codeword to activate emergency alerts.
- 💬 **Speech-to-Text Integration**: Utilizes a Speech-to-Text API for accurate and reliable voice recognition.
- 📩 **Instant SMS Alerts**: Sends real-time SOS messages via the `telephony` package to saved contacts.
- ☁️ **Firebase Backend**:
  - Firestore for secure user data and contact storage.
  - Cloud Functions for real-time backend processing.
- 📱 **User-Friendly UI**: Clean Flutter-based interface with seamless setup of contacts and codeword.

## 🛠️ Tech Stack

- **Flutter & Dart**: Frontend development
- **Firebase Firestore**: Real-time NoSQL database for storing user info
- **Firebase Cloud Functions**: Backend logic and automation
- **Speech-to-Text API**: Voice recognition engine
- **Telephony Package**: Native SMS sending on Android

## 🔒 Privacy & Security

User data is securely stored in Firestore. Codewords are locally processed to preserve user privacy. No voice data is transmitted or stored externally.

## 📷 Screenshots

<img width="300" height="600" alt="image" src="https://github.com/user-attachments/assets/9c01f6bc-d6a9-4f51-9896-ec3ea39cfac4" />

<img width="300" height="600" alt="image" src="https://github.com/user-attachments/assets/c9f88d36-4818-4238-b145-f8f9fc50555a" />

<img width="300" height="600" alt="image" src="https://github.com/user-attachments/assets/5fc60120-f4e5-426e-a09e-7acd897d6bcc" />

<img width="300" height="600" alt="image" src="https://github.com/user-attachments/assets/35391b71-b03b-4f3d-b65d-a572eb2bd50e" />

<img width="300" height="600" alt="image" src="https://github.com/user-attachments/assets/ff8b40d0-17fb-4f1e-b06e-a151f02414f5" />

<img width="300" height="600" alt="image" src="https://github.com/user-attachments/assets/cd42bd97-bb36-4c8c-ab14-09988eb29a66" />

<img width="300" height="600" alt="image" src="https://github.com/user-attachments/assets/ffcfe53f-0c79-41ac-8755-df10a6741d56" />

<img width="300" height="600" alt="image" src="https://github.com/user-attachments/assets/b56ccb53-e26d-4c71-8013-e7f570dc5865" />

## 🚀 Getting Started

1. Clone this repository.
2. Run `flutter pub get` to install dependencies.
3. Set up your Firebase project and add `google-services.json`.
4. Enable necessary permissions for microphone and SMS.
5. Run on a physical Android device.

## 📌 Future Enhancements

- Location tracking in SOS messages
- Multi-language voice recognition
- Emergency call integration
- Wearable device compatibility

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss your ideas.

## 📄 License

This project is open-source under the MIT License.

---

**Stay safe. Stay empowered.**
