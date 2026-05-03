I made this shader with a simple goal: mimicking how an electron gun’s beam softly diffuses on a CRT phosphor.
It runs as a 2-pass system (Electron Gun + Phosphor). You can adjust the Mask Scale (1x-4x) in the shader parameters to fit your screen resolution.
**Honestly, looking at the screenshots, I can't even tell the difference between the masks myself. lol.**But the actual goal was to create a "phosphor look" that feels natural and flexible across different resolutions, rather than just a fixed CRT effect.
Updating GLSL.

The color tone is slightly different from the previous version.

While creating the GLSL version, we have also added a lower-spec lite version for devices that might struggle with the system requirements.

You can run -lite within GLSL.
Updating GLSL.

The color tone is slightly different from the previous version.

While creating the GLSL version, we also added a lite version for devices that might struggle with the specifications.
It includes 3 types:
Aperture Grille
Shadow Mask
Slot Mask
[Recommended for RG406V]
Grille: 2x
Shadow: Default (1x)
Slot: 2x
It’s just something I made for fun, so please use it as a lightweight option. It should run pretty smoothly!
And I changed the existing "grill" to "grille".
