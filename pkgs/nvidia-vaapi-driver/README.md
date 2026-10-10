# nvidia-vaapi-driver patch provenance

**Source:** nixpkgs `nvidia-vaapi-driver` 0.0.18. `default.nix` overrides the
upstream package; `hosts/draba/graphics.nix` installs it through
`hardware.graphics.extraPackages` (`hardware.nvidia.videoAcceleration` is off
so the stock copy is not installed).

**Build:** `nix build .#nvidia-vaapi-driver --no-link`.

**Problem:** with two NVIDIA GPUs (5090 compute, 5060 desktop) the direct backend
always decoded on the first GPU. `init_nvdriver` opened `/dev/nvidia0` and
allocated its RM device with instance 0, and `findGPUIndexFromFd` fell back to
CUDA device 0 because `NV0000_CTRL_CMD_GPU_GET_UUID_FROM_GPU_ID` fails on the
615 driver. Frames decoded on the 5090 and exported through the 5060's DRM fd
showed green garbage in Brave. Pinning `CUDA_VISIBLE_DEVICES` instead made the
surface import fail with `invalid device ordinal`, which crashed Plex's mpv in
`vaGetImage`.

**Local changes:** `multi-gpu.patch`
- opens `/dev/nvidia<minor>` for the GPU behind the DRM fd (minor from
  `/proc/driver/nvidia/gpus/<pci>/information`; `gpu_id` is `bus << 8 | device`);
- allocates the RM device with the instance from `NV0000_CTRL_CMD_GPU_GET_ID_INFO_V2`;
- when the UUID match fails, matches the CUDA device by PCI bus before falling
  back to device 0.

**Verified (2026-10-09):** ffmpeg VA-API on `renderD128` and `renderD129` picks
`/dev/nvidia0`/instance 0 and `/dev/nvidia1`/instance 1, no CUDA errors; Brave
VP9 playback decodes on the 5060 (NVDEC busy on GPU 1, not GPU 0) with a
correct picture, where the stock driver decoded on GPU 0 and showed green.

**Upstream:** elFarto/nvidia-vaapi-driver; not sent.

**Updating:** the patch must still apply; rebase it if it does not.

**Removal condition:** drop the patch and restore `videoAcceleration` once
upstream selects the device from the DRM fd on multi-GPU systems.
