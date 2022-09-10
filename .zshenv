function run() {
    neofetch
}

OUTPUT=1

if [[ ! -o interactive ]]; then
    OUTPUT=3
    eval "exec $OUTPUT<>/dev/null"
fi

run >& $OUTPUT

if [[ ! -o interactive ]]; then
   eval "exec $OUTPUT>&-"
fi
