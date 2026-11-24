## Camping Kit 1.11.2

**Fix: "You are doing this too quickly"**
- The game only lets you join and leave chat channels so fast. The kit could ask faster than that, mostly just after logging in or a /reload, when it left all its leftover camp channels at once and asked again every 5 seconds for any still there. Each request the game turned down printed "You are doing this too quickly", over and over.
- Now the kit asks for one join or leave at a time, a few seconds apart. If a leave doesn't go through, it waits longer each time before asking again (10 seconds, then 20, 40 and so on, up to 5 minutes).
- After a /reload the kit no longer leaves your zone's camp channel only to join it again a moment later.
- If something else takes you out of a kit channel (a /leave, another addon), the kit waits 30 seconds before joining again, and longer if it keeps happening, instead of trying straight away.

**Fix: "Joined Channel" and "Left Channel" lines in chat**
- Since 1.11 the kit moves to your zone's hidden camp channel as you travel, and the game printed "Joined Channel: [6. CKH1L618Z1411]" or "Left Channel: …" in chat every time. The kit now hides those lines, and any "joined" or "left" lines for its channels.
- The same goes for the kit leaving the old CampingKitNet channel, and Happy Camper's channel if you don't have Happy Camper installed.
- Only the kit's own channels are hidden: General, Trade and every other channel show their lines as before.
- The kit's channels are kept out of your chat windows again. Since the game's chat update this had stopped working on some setups.

**Also**
- `/ck net` lists any channel the kit is still waiting to leave, and when it will ask again.
- Turning off "Tuck at screen edge" now keeps the kit fully on screen on its edge. Before, the setting did nothing unless another kit you had installed brought a newer Kit Dock with it.
- Moving the mouse over a reminder or pinned button beside a tucked kit no longer slides the kit out. Only the kit itself (or its kit box) does.
