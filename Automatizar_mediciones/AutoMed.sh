# Lista generada con Generador_listas.hs (comandos_test)
tests=(
  "iobench > 0cpu1io_io1 &"
  "iobench > 0cpu2io_io1 &\niobench > 0cpu2io_io2 &"
  "cpubench > 1cpu0io_cpu1 &"
  "cpubench > 1cpu1io_cpu1 &\niobench > 1cpu1io_io1 &"
  "cpubench > 1cpu2io_cpu1 &\niobench > 1cpu2io_io1 &\niobench > 1cpu2io_io2 &"
  "cpubench > 2cpu0io_cpu1 &\ncpubench > 2cpu0io_cpu2 &"
  "cpubench > 2cpu1io_cpu1 &\ncpubench > 2cpu1io_cpu2 &\niobench > 2cpu1io_io1 &"
  "cpubench > 2cpu2io_cpu1 &\ncpubench > 2cpu2io_cpu2 &\niobench > 2cpu2io_io1 &\niobench > 2cpu2io_io2 &"
)

# Ejecutar desde carpeta xv-modularized y después de hacer make qemu
(
  for i in {0..7}; do
    (sleep 2; echo -e "${tests[i]}") | timeout 302 make qemu-nox CPUS=1
  done;
)


