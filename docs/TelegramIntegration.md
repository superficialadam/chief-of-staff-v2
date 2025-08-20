# Prompt: Implement Telegram webhook integration for Rails app with Kamal 2

I want to implement **Telegram messaging/webhooks** for this app. Requirements:

I have done a successful connection in another project that you have access to in ../chief-of-staff
All the credentials, bot name etc are there as well as a message formatter and a controller.
PLEASE DONT IMPLEMENT ANY FUNCTIONALITY other than the TELEGRAM CONNECTION from that project. 
Use the controller and formatter as a reference to connect, 
but dont inherit a bunch of irreleavant functions to this project.

- The webhook endpoint should live under the same domain as the app:  
  `https://cos.dev.its75am.com/webhooks/telegram`.

- It should support **two modes**:
  1. **Local development**: Rails runs on my Mac at `localhost:3000`. I want to forward Telegram webhooks through the server using a reverse tunnel (server:4000 → mac:3000). Kamal proxy should forward `/webhooks/telegram` to `127.0.0.1:4000` when I’m in dev mode, so Telegram traffic goes to my local Rails.
  2. **Production**: When deployed, the webhook should be routed directly to the Rails container on the Hetzner server via Kamal proxy. No tunnel. Same stable webhook URL is used in both dev and prod.

- I need you to:
  - Configure Kamal proxy to forward `/webhooks/telegram` properly in both dev and prod.
  - Write the Rails controller
  - Register the webhook URL with Telegram using `setWebhook`.
  - Connect the current ai chat to recieve and respond to the Telegram bot.

- Important: The **webhook URL must not change** between dev and prod.  
  (In dev it routes through reverse tunnel → Mac; in prod it routes directly to container.)

Please generate the Rails code, Kamal config changes, and CLI commands to set this up end-to-end.

As you see in this projects .env I use 1password for all secrets. 
Follow the op://Dev/cos_app/* pattern for the Telegram Environements needed


