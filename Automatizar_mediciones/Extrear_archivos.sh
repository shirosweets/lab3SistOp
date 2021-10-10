# Lista generada con Generador_listas.hs (archivos_test)
archivos=(
  "0cpu1io_iobench1.txt"
  "0cpu2io_iobench1.txt"
  "0cpu2io_iobench2.txt"
  "1cpu0io_cpubench1.txt"
  "1cpu1io_cpubench1.txt"
  "1cpu1io_iobench1.txt"
  "1cpu2io_cpubench1.txt"
  "1cpu2io_iobench1.txt"
  "1cpu2io_iobench2.txt"
  "2cpu0io_cpubench1.txt"
  "2cpu0io_cpubench2.txt"
  "2cpu1io_cpubench1.txt"
  "2cpu1io_cpubench2.txt"
  "2cpu1io_iobench1.txt"
  "2cpu2io_cpubench1.txt"
  "2cpu2io_cpubench2.txt"
  "2cpu2io_iobench1.txt"
  "2cpu2io_iobench2.txt"
)

for i in {0..17}; do
  (sleep 1; echo "cat ${archivos[i]}") | make qemu-nox CPUS=1 | tail --lines=+14 | head --bytes=-2 > "${archivos[i]}" &
    # El archivo en si empieza siempre en la linea 15
    # Los últimos 2 caracteres son "$ " de después de la ejecución del cat
  sleep 2
  pkill qemu
done;

