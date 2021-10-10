
# Lista generada con Generador_listas.hs
xs=(
    "iobench > 0cpu1io_iobench1.txt &\n"
    "iobench > 0cpu2io_iobench1.txt &\niobench > 0cpu2io_iobench2.txt &\n"
    "cpubench > 1cpu0io_cpubench1.txt &\n"
    "cpubench > 1cpu1io_cpubench1.txt &\niobench > 1cpu1io_iobench1.txt &\n"
    "cpubench > 1cpu2io_cpubench1.txt &\niobench > 1cpu2io_iobench1.txt &\niobench > 1cpu2io_iobench2.txt &\n"
    "cpubench > 2cpu0io_cpubench1.txt &\ncpubench > 2cpu0io_cpubench2.txt &\n"
    "cpubench > 2cpu1io_cpubench1.txt &\ncpubench > 2cpu1io_cpubench2.txt &\niobench > 2cpu1io_iobench1.txt &\n"
    "cpubench > 2cpu2io_cpubench1.txt &\ncpubench > 2cpu2io_cpubench2.txt &\niobench > 2cpu2io_iobench1.txt &\niobench > 2cpu2io_iobench2.txt &\n"
)

(
    for i in {0..7}; do
        (sleep 2; echo -e "${xs[i]}") | make qemu-nox CPUS=1 > /dev/null &
        sleep 302 # 2+5*60
        pkill qemu
    done;
) > /dev/null



