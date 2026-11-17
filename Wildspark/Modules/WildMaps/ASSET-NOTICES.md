# Asset and source notices

This package includes client-referenced and bundled map imagery with the
sources described below. The approved cleaned RFD Approach tiles are retained
without further artwork changes.

## Blizzard-derived imagery

HiddenMaps is an independent World of Warcraft addon, not affiliated with or
endorsed by Blizzard Entertainment. World of Warcraft and the underlying
Blizzard game artwork remain the property of Blizzard Entertainment. Certain
HiddenMaps textures are derived from Blizzard game, world, or minimap assets;
HiddenMaps does not claim ownership of that artwork. Any licence applying to
HiddenMaps' own code or original material does not purport to grant rights to
Blizzard-owned assets. This notice is not a redistribution licence.

## Santiago Reyes maps added in dev10

The Hall of Thanes, Ruins of Lordaeron, and Excavation Site: Wetlands use artwork
by **Santiago Reyes — Atlas de Azeroth: Forever**, supplied by the project owner.
These are the creator's artistic interpretations, not Blizzard-authored maps.

The complete 1600×1067 images and embedded watermarks are preserved. Conversion
only decodes the JPEGs and partitions their pixels into lossless TGA tiles;
there is no resizing, color correction, retouching, or removal of attribution.
Transparent technical padding outside the image bounds is not displayed.
The addon adds the requested text credit below the artwork.

Creator's project and published usage guidelines (checked 6 October 2026):
https://asguevara433.wixsite.com/srmaps/post/proyecto-atlas-de-azeroth-forever

The creator asks users to retain the watermark, provide credit, and respect the
artwork; the project page states there is no charge for use. This attribution
does not imply affiliation with or endorsement by Blizzard. Original JPEGs and
their hashes are retained in the separate development/source archive.

## Artwork inherited from beta1

- Most dungeon artwork is referenced from client-provided
  `Interface/Worldmap/...` paths and is not bundled in this ZIP.
- The project handoff identifies custom approach/WMO map artwork as derived
  from World of Warcraft minimap/WMO exports. Ragefire Chasm retains its existing
  WMO-based interior exception.
- The two bundled entrance icons and universal background are inherited
  unchanged. Their individual authorship/license documentation was not
  established by the supplied release materials.
- Eight unused faction-strip textures were preserved in the separate cleanup
  archive and are omitted from this installable package.
- Scholomance uses the supplied Candidate A clean native Forever minimap masters
  for WMO 3293, baked 90 degrees clockwise into lossless RGBA TGA tiles. Source
  pixels, alpha and the cyan Lower Vaults imagery are preserved. It does not use
  AtlasMaps artwork. The Santiago Reyes maps described above belong to his
  Atlas de Azeroth project.

No standalone LICENSE file or source-code license statement is included in the
current addon package. This release does not select a new license or claim permission to redistribute
third-party artwork. The project owner still needs to settle the code license
and confirm the relevant asset permissions before public distribution.
