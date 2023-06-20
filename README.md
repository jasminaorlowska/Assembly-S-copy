# Assembly-S-copy
computer architecture and organization assembly project

**The program filters the data during the copy process, preserving only specified characters.**

Usage instruction: ./scopy in_file out_file

**Description**

The scopy program takes two parameters: in_file (the source file) and out_file (the destination file).
The program performs the following actions:

It checks the number of parameters.
If the number of parameters is not equal to 2, the program terminates with an exit code of 1.

The program attempts to open the in_file for reading. 
If the file opening fails, the program terminates with an exit code of 1.

The program attempts to create the out_file with read and write permissions (-rw-r--r--).
If the file creation fails, for example, if the file already exists, the program terminates with an exit code of 1.

The program reads from the in_file and writes to the out_file.
If there is an error during the read or write operations, the program terminates with an exit code of 1.

For each byte read from the in_file that has an ASCII value of 's' or 'S', the program writes that byte to the out_file.

For each maximal non-empty sequence of bytes read from the in_file that does not contain the byte with an ASCII value of 's' or 'S',
the program writes a 16-bit number to the out_file. The number represents the count of bytes in the sequence modulo 65536.
The number is written in little-endian binary format.

Finally, the program closes the files and if everything succeeded, it terminates with an exit code of 0.
