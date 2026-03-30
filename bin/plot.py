#!/usr/bin/env python3

import os, sys, re, argparse, gzip
import numpy as np
import matplotlib.pyplot as plt

def expand_path(fn):
	return os.path.expanduser(os.path.expandvars(fn))

def Open(fn, mode='r', **kwargs):
	if fn == '-':
		return sys.stdin if mode.startswith('r') else sys.stdout
	fn = expand_path(fn)
	return gzip.open(fn, mode, **kwargs) if fn.lower().endswith('.gz') else open(fn, mode, **kwargs)


def main():
	parser = argparse.ArgumentParser(description="GPRO RAG Training")
	parser.add_argument("--input-file", '-i', default='-', help="input file")
	args = parser.parse_args()

	# 1. Read numbers from stdin, ignoring non-numeric or empty lines
	regex = re.compile(r'[^0-9\.-]')
	data = []
	for line in Open(args.input_file):
		items = regex.sub(' ', line.strip()).split()
		if items:
			try:
				data.append([float(x) for x in items])
			except:
				continue

	if not data:
		print("No valid numeric data received.")
		return

	cols = min([len(d1) for d1 in data])

	# 2. Create the plot
	plt.figure(figsize=(10, 6))
	for i in range(cols):
		plt.plot(np.array([d1[i] for d1 in data]), marker='o', linestyle='-', label=f'Column {i}')
	
	# 3. Customize the chart
	plt.title('Data Plot from Standard Input')
	plt.xlabel('Index (Sequence)')
	plt.ylabel('Value')
	plt.grid(True)
	plt.legend()
	
	# 4. Display the plot
	plt.show()

if __name__ == "__main__":
	main()
