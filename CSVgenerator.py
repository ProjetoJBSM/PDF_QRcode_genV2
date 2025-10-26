import os
import csv
import random
import string

filePath = 'data.csv'
numRows = 2000
numCols = 2
colNames = ['valor', 'nome_arquivo']
baseLink = "http://teste.com/"


with open(filePath, mode='w', newline='') as file:
    writer = csv.writer(file)
    writer.writerow(colNames)
    for i in range(numRows):
        row = [baseLink + str(i), f"file_{i}.txt"]
        writer.writerow(row)