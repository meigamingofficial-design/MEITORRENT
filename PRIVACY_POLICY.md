# Privacy Policy – Meitorrent

**Last Updated:** May 07, 2026

Meitorrent is built, published, and maintained by **MeiGamingOfficial** ("we", "our", or "us"). Meitorrent is designed with privacy as a fundamental priority. We do not collect, transmit, store, or share any personal information, usage data, or download logs. All torrent metadata and downloads are stored purely locally on your own device.

---

### 1. Zero Data Collection & Safety Compliance
- **No Personal Data:** We do not collect names, email addresses, phone numbers, location data, or device identifiers. No user account registration is required to use Meitorrent.
- **No Tracking or Analytics:** We do not track your app usage, search history, file lists, or download logs. We do not use any third-party analytics or behavioral tracking SDKs.
- **Data Deletion:** Since we do not collect any user data on any central servers, we have no user data to delete or manage. All your downloaded content and app state are managed locally on your device and can be removed at any time by clearing the app data or uninstalling the app.

### 2. Networking and Peer-to-Peer (P2P) Communication
Meitorrent is a BitTorrent file-transfer client. To function, it facilitates direct peer-to-peer (P2P) connections between your device and other users (peers) in the network.
- **IP Address Visibility:** When actively downloading or uploading a torrent, your public IP address is visible to other participants (peers) in the same torrent swarm. This is an immutable technical requirement of the BitTorrent protocol itself.
- **Direct Data Transfer:** All payload bytes are transferred directly between your device and other peers. We do not host, broker, facilitate, or witness these file transfers.

### 3. Third-Party Services
- **Local Assets & Offline Operation:** To guarantee absolute privacy and offline capability, all UI assets—including our Shippori Mincho typography—are bundled and loaded locally from your device. The app makes zero external network requests to online font servers (such as Google Fonts) during runtime.
- **Firebase Crashlytics:** To actively monitor and improve app stability, Meitorrent uses Firebase Crashlytics (a service provided by Google). When a crash or a non-fatal error occurs, basic diagnostic information (such as stack traces, device model, operating system version, and custom debug logs) is collected and transmitted. This diagnostic data contains no personally identifiable information and is used solely to identify and fix technical issues, in compliance with Google's Privacy Policy (https://policies.google.com/privacy).


### 4. Android Device Permissions & Usage Disclosures
To provide a reliable file-transfer utility, Meitorrent requires the following system permissions, which are strictly limited to technical functionality:
- **INTERNET & Network State (`android.permission.INTERNET`, `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`):** Required to connect to trackers, DHT, peer exchanges, and peers over the BitTorrent network.
- **Storage/Media Access:** Used strictly to save downloaded torrent files to your chosen local directory and to read `.torrent` files you open with the app.
- **Foreground Service (`android.permission.FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`):** Used to run a background data-synchronization service. This keeps your active torrent downloads running reliably when the app is placed in the background or when your screen is locked. A persistent status notification is shown to you during this activity.
- **Notifications (`android.permission.POST_NOTIFICATIONS`):** Used on Android 13+ to display the real-time download progress bar in your device’s status notification tray.
- **Battery Optimization Settings:** Used to prompt you to exclude Meitorrent from aggressive system battery savers, preventing your downloads from being terminated prematurely when the device goes to sleep.

---

### 5. Legal & Contact Information
For any privacy questions, license inquiries, or support requests regarding Meitorrent, please contact us at:

**MeiGamingOfficial**  
Email: **meigaming.official@gmail.com**  
GitHub: https://github.com/meigamingofficial-design
