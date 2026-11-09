# AOT student portal

Responsive student-services site and portal preview built with native HTML, CSS, and JavaScript. No framework, TypeScript, package installation, or build step is required at runtime.

## Run locally

Use Node.js 18+ and run `npm start`, then visit the local URL printed by the server. For development without Node, serve this directory with any static HTTP server.

Set `AOT_WHATSAPP_NUMBER` in the page as `window.AOT_WHATSAPP_NUMBER = '234...'` before `src/app.js` to enable direct WhatsApp links. Without a configured number, the page copies the prepared message where browser permissions allow it.

The site includes the public services, package estimator, demo admission tracking, student dashboard and application form, admin preview, responsive navigation, login/register preview, and contact-to-WhatsApp interactions. No backend or live integrations are connected. Demo rows and progression are illustrative, admin changes and file selection remain local, and admission chance is intentionally not calculated without verified institution requirements and a validated method.

Run `npm test` for lightweight renderer and static-runtime checks.
