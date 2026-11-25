# Sourced by setup.sh and session.sh. Usage: source env.sh <gpu|software>
export WINEPREFIX=/root/.wine
export WINEDEBUG=-all
export WINEARCH=win64
export BOX64_NOBANNER=1
export BOX64_LOG=0
export BOX64_DYNAREC=1
export BOX64_DYNAREC_BIGBLOCK=1
export BOX64_DYNAREC_STRONGMEM=0
export BOX64_DYNAREC_FASTNAN=1
export BOX64_DYNAREC_FASTROUND=1
export BOX64_DYNAREC_SAFEFLAGS=1
export BOX64_DYNAREC_CALLRET=1
export PATH=/opt/wine/bin:$PATH
export LIBGL_ALWAYS_SOFTWARE=
export MESA_SHADER_CACHE_DIR=/root/.cache/mesa
export DXVK_STATE_CACHE_PATH=/root/.cache/dxvk
export DXVK_LOG_LEVEL=none
mkdir -p /root/.cache/mesa /root/.cache/dxvk
if [ "$1" = "gpu" ] && [ -f /usr/share/vulkan/icd.d/freedreno_icd.aarch64.json ]; then
  export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json
  export TU_DEBUG=noconform
  # Xvfb has no DRI3, so present frames through Mesa's CPU (software) WSI path
  export MESA_VK_WSI_DEBUG=sw
  export MESA_VK_WSI_PRESENT_MODE=mailbox
  export WINEDLLOVERRIDES="d3d8,d3d9,d3d10core,d3d11,dxgi=n,b"
  export PCEMU_RENDERER=gpu
else
  export GALLIUM_DRIVER=llvmpipe
  export LIBGL_ALWAYS_SOFTWARE=1
  export WINEDLLOVERRIDES="d3d8,d3d9,d3d10core,d3d11,dxgi=b"
  export PCEMU_RENDERER=software
fi
