# Client soundbanks

This distribution includes the complete catalog and soundbank for protocol
15.30 in `1530/`. Keep its catalog, `.dat` soundbank and referenced `.ogg`
files together. The client selects the folder matching the client version.

Incomplete legacy catalogs and loose legacy sound files are not shipped.
Do not copy a 15.30 catalog into another version's folder: numeric sound IDs
and the referenced files must match that version's bank.

## Adding client versions

Create a version folder and copy the complete soundbank into it, then run
`python tools/validate_repository.py` from the repository root.

For the list of supported client versions see `modules/gamelib/game.lua`

# Example configuration

`data/sounds/1340/ (catalog-sound.json and all sound files)`
