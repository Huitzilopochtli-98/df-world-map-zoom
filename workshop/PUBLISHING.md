# Publishing the Workshop companion

This is a setup/help companion for the native World Map Zoom 1.0.0 release.
It is not a Subscribe-and-play port of the renderer. The title, description,
README, and help command must continue to make manual installation explicit.

## Steam identity

Steam records the uploading account as the item's owner and publicly attributes
published content to its profile. A generic `AUTHOR` tag does not hide that
account. Private profile settings or a renamed display name do not remove the
item's owner SteamID. There is no anonymous publishing option.

Use the account you intend to associate publicly with the project. A separate
pseudonymous account separates public profiles, but it still has its own Steam
identity. Do not upload from a personal account if that association is unwanted.
Accounts need Workshop submission access and an eligible game/tool license;
limited accounts and Family Sharing licenses cannot submit Workshop content.

## Build the upload folder

From a committed checkout:

```powershell
python tools/package_workshop.py --output dist/workshop-1.0.0
```

The output includes the mod folder, an upload ZIP, its checksum, this guide, and
the full Steam BBCode description. The package builder does not sign into Steam,
inspect accounts, copy into the game, or upload anything. Existing outputs are
never overwritten, so a generated Steam item ID cannot be accidentally discarded.

## Upload

1. Sign into Steam with the intended publishing account. The upload will link
   that profile to this project. Check the account before starting the game.
2. Copy the generated `worldmap-zoom-companion` folder into
   `Dwarf Fortress/mods/mod_upload/`.
3. Launch DF through Steam. Open **Mods** on the title screen and use its upload
   function to submit the companion. The game manages Steam authentication.
4. Follow any Steam Workshop agreement or email-verification prompts yourself.
5. Open the uploaded item and replace its short description with the contents
   of `WORKSHOP_DESCRIPTION.bbcode`. Confirm the manual-install notice and links.
6. Keep the `STEAM_FILE_ID` that Steam adds to the upload folder's `info.txt`.
   Reuse it for updates to the same listing; do not generate duplicate items.
7. Check the published download from a clean test setup: the companion should
   expose `worldmap-zoom-setup` with DFHack running, while the separately installed
   Windows package supplies `gui/worldmap-zoom`.

The uploader may publish immediately. Changing visibility afterward does not
provide anonymous authorship. Do not start an upload on the wrong account.

The preview is copied unchanged from the existing fortress screenshot. No game
executable, native DLL, installer, save, or personal account data is in this
companion. It is not necessary to modify game objects or create a new world.

References:

- [DFHack Workshop script layout](https://docs.dfhack.org/en/53.16-r3/docs/guides/modding-guide.html#what-if-i-just-want-to-distribute-a-simple-standalone-script)
- [Bay 12 upload guide](https://www.bay12games.com/dwarves/modding_guide.html)
- [Steam public profile names](https://help.steampowered.com/en/faqs/view/56C6-D584-CC80-4EB2)
- [Steam item ownership](https://partner.steamgames.com/doc/api/ISteamUGC#SteamUGCDetails_t)
- [Limited accounts](https://help.steampowered.com/en/faqs/view/71D3-35C2-AD96-AA3A)
- [Game/tool license requirements](https://partner.steamgames.com/doc/features/workshop#FrequentlyAskedQuestions)
