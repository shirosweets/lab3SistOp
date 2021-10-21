# Lista generada con Generador_listas.hs (archivos_test)
archivos=(
  "0cpu1io_io1"
  "0cpu2io_io1"
  "0cpu2io_io2"
  "1cpu0io_cpu1"
  "1cpu1io_cpu1"
  "1cpu1io_io1"
  "1cpu2io_cpu1"
  "1cpu2io_io1"
  "1cpu2io_io2"
  "2cpu0io_cpu1"
  "2cpu0io_cpu2"
  "2cpu1io_cpu1"
  "2cpu1io_cpu2"
  "2cpu1io_io1"
  "2cpu2io_cpu1"
  "2cpu2io_cpu2"
  "2cpu2io_io1"
  "2cpu2io_io2"
)

# Ejecutar desde carpeta xv-modularized y después de ejecutar AutoMed.sh (sin borrar fs.img en el medio)
for i in {0..17}; do
  (sleep 1; echo "cat ${archivos[i]}") | timeout 2 make qemu-nox CPUS=1 | tail --lines=+14 | head --bytes=-2 > "../Mediciones/${archivos[i]}"
    # El archivo en si empieza siempre en la linea 15
    # Los últimos 2 caracteres son "$ " de después de la ejecución del cat
done;

