import os
import ast
import statistics as st

# FOLDERS = ["mediciones_TF", "mediciones_IR", "mediciones_VV"]
FOLDERS = ["mediciones_VV"]


def process_folder(folder_path):
    print(f"Processing folder: {folder_path}")
    files = os.listdir(os.path.abspath(folder_path))
    for fl in files:
        process_file(folder_path, fl)


def stastistical_analysis(measurements):
    av = st.mean(measurements)
    deviation = st.stdev(measurements)
    median = st.median(measurements)
    return av, deviation, median


def process_file(folder, filename):
    print(f"Processing file {filename}")
    absp_file = os.path.abspath(f"{folder}/{filename}")
    measurements = []
    counted_measurements = 0
    with open(absp_file, "r") as f:
        for line in f:
            try:
                measurement = ast.literal_eval(line.split()[-2])
                measurements.append(measurement)
                counted_measurements += 1
            except Exception:
                print(f"Could not parse line: {line.split()}")
    av, stdv, median = stastistical_analysis(measurements)
    print(
        f"{folder}/{filename} :: promedio {av}, "
        f"desviación estandar {stdv}, mediana {median}, "
        f"medidas {counted_measurements}"
    )


if __name__ == "__main__":
    for folder in FOLDERS:
        process_folder(folder)
