# Security policy

## Supported version

Security fixes target the latest source version on the default branch.

## Important network warning

DeskWeave 0.3 uses an unauthenticated, unencrypted TCP stream on port `5900`.
Anyone able to reach the Mac on that port may connect to the video stream.

- Use only a trusted private network.
- Do not configure router port forwarding for DeskWeave.
- Do not use it on public, hotel, airport, or untrusted shared Wi-Fi.
- Stop the Mac app when the second display is not in use.

DeskWeave captures only its virtual display, but users are responsible for the
content placed on that display.

## Reporting a vulnerability

Do not open a public issue for a vulnerability. Use GitHub's private
**Security → Report a vulnerability** flow after the repository enables private
vulnerability reporting. Include the affected version, impact, reproduction
steps, and any proposed mitigation.

No bug bounty is offered at this stage. Please allow reasonable time for a fix
before public disclosure.

