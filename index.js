const express = require('express');
const cors = require('cors');
const OneSignal = require('onesignal-node');

const app = express();
app.use(cors());
app.use(express.json());

const client = new OneSignal.Client({
  appId: 'YOUR_ONESIGNAL_APP_ID',           // from OneSignal dashboard
  restApiKey: 'YOUR_ONESIGNAL_REST_API_KEY', // from OneSignal dashboard
});

app.post('/send-notification', async (req, res) => {
  const { userIds, message, sessionId } = req.body;

  if (!userIds || userIds.length === 0) {
    return res.status(400).json({ error: 'No recipients' });
  }

  const notification = {
    contents: { en: message || 'Someone is sharing their live location.' },
    headings: { en: '📍 Track My Trip' },
    include_external_user_ids: userIds,
    data: { type: 'tracking', sessionId },
  };

  try {
    const response = await client.createNotification(notification);
    console.log('Notification sent:', response.body);
    res.json({ success: true });
  } catch (e) {
    console.error('Error sending notification', e);
    res.status(500).json({ error: e.message });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));