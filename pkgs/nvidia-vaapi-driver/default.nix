{ nvidia-vaapi-driver }:
nvidia-vaapi-driver.overrideAttrs (old: {
  # The direct backend otherwise decodes on the first GPU, whatever card it is given
  patches = (old.patches or [ ]) ++ [ ./multi-gpu.patch ];
})
