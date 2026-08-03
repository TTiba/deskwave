# Privacy

DeskWeave does not collect, store, or transmit analytics, telemetry, account
information, advertising identifiers, or personal data to a cloud service.

The macOS app requests:

- **Screen Recording** to capture the virtual display it creates;
- **Local Network** access to send that display to the tablet.

The Android app requests network access and keeps the device awake while the
stream is active. It does not request access to files, contacts, location,
camera, microphone, or accounts.

Video travels directly from the Mac to the Android tablet over the local
network. Version 0.3 does not encrypt or authenticate that connection, so it
must be used only on a trusted private network. Content placed on the virtual
display may be visible to another client that can reach the Mac on TCP port
5900.

