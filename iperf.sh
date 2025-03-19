#!/bin/bash

SERVER_IP="192.168.30.82"
DURATION=5
INTERVAL=1

OUTPUT_DIR="iperf_results"
mkdir -p $OUTPUT_DIR

echo "Esecuzione dei test di rete con iPerf3..."

# Funzione per estrarre dati JSON in CSV
extract_json() {
    local json_file=$1
    local csv_file=$2
    jq -r '.intervals[] | [.sum.start, .sum.bits_per_second] | @csv' "$json_file" > "$csv_file"
}

# Test 1: TCP throughput bidirezionale
iperf3 -c $SERVER_IP -t $DURATION --json > $OUTPUT_DIR/tcp_bidirectional.json
extract_json "$OUTPUT_DIR/tcp_bidirectional.json" "$OUTPUT_DIR/tcp_bidirectional.csv"

# Test 2: UDP test per latenza e jitter
iperf3 -c $SERVER_IP -u -b 100M -t $DURATION -i $INTERVAL --json > $OUTPUT_DIR/udp_test.json
extract_json "$OUTPUT_DIR/udp_test.json" "$OUTPUT_DIR/udp_test.csv"

# Test 3: Multi-thread TCP
iperf3 -c $SERVER_IP -P 10 -t $DURATION --json > $OUTPUT_DIR/tcp_multithread.json
extract_json "$OUTPUT_DIR/tcp_multithread.json" "$OUTPUT_DIR/tcp_multithread.csv"

# Test 4: Reverse mode (server → client)
iperf3 -c $SERVER_IP -R -t $DURATION --json > $OUTPUT_DIR/tcp_reverse.json
extract_json "$OUTPUT_DIR/tcp_reverse.json" "$OUTPUT_DIR/tcp_reverse.csv"

echo "Pulizia risultati.."

sed -i 's/ //g' $OUTPUT_DIR/tcp_bidirectional.csv
tr -d '\r' < $OUTPUT_DIR/tcp_bidirectional.csv > temp.csv && mv temp.csv $OUTPUT_DIR/tcp_bidirectional.csv

sed -i 's/ //g' $OUTPUT_DIR/udp_test.csv
tr -d '\r' < $OUTPUT_DIR/udp_test.csv > temp.csv && mv temp.csv $OUTPUT_DIR/udp_test.csv

sed -i 's/ //g' $OUTPUT_DIR/tcp_multithread.csv
tr -d '\r' < $OUTPUT_DIR/tcp_multithread.csv > temp.csv && mv temp.csv $OUTPUT_DIR/tcp_multithread.csv


echo "Generazione grafici con Gnuplot..."

# Genera script Gnuplot
cat << EOF > $OUTPUT_DIR/grafico.plt
set terminal pngcairo size 800,600 enhanced font 'Arial,12'
set grid
set datafile separator ","
set xrange [*:*]

set output "iperf_results/tcp_bidirectional.png"
set title "Throughput TCP Bidirezionale"
set xlabel "Tempo (s)"
set ylabel "Throughput (Mbps)"
plot "iperf_results/tcp_bidirectional.csv" using 1:(\$2/1e6) with lines linewidth 2 title "TCP Bidirezionale"

set output "iperf_results/udp_test.png"
set title "Throughput UDP (100 Mbps)"
set xlabel "Tempo (s)"
set ylabel "Throughput (Mbps)"
plot "iperf_results/udp_test.csv" using 1:(\$2/1e6) with lines linewidth 2 title "UDP Test"

set output "iperf_results/tcp_multithread.png"
set title "Throughput TCP Multi-Thread (10 connessioni)"
set xlabel "Tempo (s)"
set ylabel "Throughput (Mbps)"
plot "iperf_results/tcp_multithread.csv" using 1:(\$2/1e6) with lines linewidth 2 title "TCP Multi-Thread"

set output "iperf_results/tcp_reverse.png"
set title "Throughput TCP Reverse Mode"
set xlabel "Tempo (s)"
set ylabel "Throughput (Mbps)"
plot "iperf_results/tcp_reverse.csv" using 1:(\$2/1e6) with lines linewidth 2 title "TCP Reverse Mode"
EOF

# Esegui gnuplot per generare i grafici
gnuplot $OUTPUT_DIR/grafico.plt

echo "Test completati! Grafici generati in $OUTPUT_DIR/"
