
xs=("iobench > 1io_io1.txt &" "iobench > 1io1cpu_io1.txt & \n cpubench > 1io1cpu_cpu1.txt")

for x in $xs;
    do
    gnome-terminal -e "bash -c '(sleep 1 ; echo \"$x\") | make qemu'"
    sleep 15 #301 # 1+5*60
    pkill qemu
done;



