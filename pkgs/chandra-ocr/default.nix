{
  chandraSrc,
  cudaPackages_13,
  lib,
  python3Packages,
}:
let
  py = python3Packages;
  flags = cudaPackages_13.flags // {
    gencodeString = "-gencode=arch=compute_120,code=sm_120";
    cmakeCudaArchitecturesString = "120";
  };
  nccl = cudaPackages_13.nccl.override { inherit flags; };
  cuda = cudaPackages_13 // {
    inherit nccl;
    libnvshmem = cudaPackages_13.libnvshmem.override { inherit flags nccl; };
  };
  triton = py.triton-bin.overrideAttrs (old: {
    # nixpkgs' binary patch returns a filename instead of a list of directories
    postFixup = old.postFixup + ''
      substituteInPlace "$out/${py.python.sitePackages}/triton/backends/nvidia/driver.py" \
        --replace-fail "return '/run/opengl-driver/lib/libcuda.so'" \
          "return ['/run/opengl-driver/lib']"
    '';
  });
  torch = py.torch-bin.override {
    cudaPackages = cuda;
    inherit triton;
  };
  torchvision = (py.torchvision.override { inherit torch; }).overrideAttrs (old: {
    env = old.env // {
      TORCH_CUDA_ARCH_LIST = "12.0";
    };
  });
  accelerate = py.accelerate.override { inherit torch torchvision; };
  causal-conv1d = py.causal-conv1d.override {
    inherit torch;
    cudaPackages = cudaPackages_13;
    cudaSupport = true;
  };
  fla = py.flash-linear-attention.override { inherit torch triton; };
in
py.buildPythonApplication {
  pname = "chandra-ocr";
  version = (builtins.fromTOML (builtins.readFile "${chandraSrc}/pyproject.toml")).project.version;
  src = chandraSrc;
  pyproject = true;

  build-system = [ py.setuptools ];
  pythonRelaxDeps = [ "markdownify" ];
  postPatch = ''
    substituteInPlace chandra/scripts/cli.py \
      --replace-fail 'click.echo(f"  Error processing {file_path.name}: {e}", err=True)' \
        'raise click.ClickException(f"Error processing {file_path.name}: {e}") from e' \
      --replace-fail '            continue' ""
  '';
  dependencies =
    with py;
    [
      beautifulsoup4
      click
      filetype
      markdownify
      openai
      pillow
      pydantic
      pydantic-settings
      pypdfium2
      python-dotenv
      six
      transformers
    ]
    ++ [
      torch
      torchvision
      accelerate
      causal-conv1d
      fla
    ];

  # Upstream tests require model downloads and a physical GPU
  doCheck = false;
  pythonImportsCheck = [
    "chandra.model"
    "chandra.scripts.cli"
  ];

  meta = {
    description = "Chandra 2 document OCR with native CUDA inference";
    homepage = "https://github.com/datalab-to/chandra";
    license = lib.licenses.asl20;
    mainProgram = "chandra";
    platforms = [ "x86_64-linux" ];
  };
}
