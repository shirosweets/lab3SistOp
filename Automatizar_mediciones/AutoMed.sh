
xs=(
    "iobench > 1io_io1.txt &"
    "iobench > 1io1cpu_io1.txt & \n cpubench > 1io1cpu_cpu1.txt &"
)

(
    for i in 0 1;
        do
        echo -e "${xs[i]}"
        (sleep 2; echo -e "${xs[i]}") | make qemu-nox > output.temp &
        sleep 2 #302 # 2+5*60
        pkill qemu
    done;
) > output.temp

rm output.temp



