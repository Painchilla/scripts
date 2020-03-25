##This Script is an Example for Automated File Compression and Encryption

##Step one: Get Files (Via tar or dd)
#dd if=input
#tar -cf - /input_Dir1 /input_Dir2 /input_file1.txt

##Step two: Compress Data
#bzip2 -9
#gzip -9
#lz4 -9
#gzip -9
##Or for Faster Compression (with Multithreading)
#lbzip2 -9
#pigz -9

##Step 3 Encrypt Data
##With Passwordfile
#openssl enc -aes-256-cbc -salt -in - out - -pass file:/home/user/pw.txt 
## Or Specify Password inline
#openssl enc -aes-256-cbc -salt -in - out - -pass pass:MySecretPassword

##Step 4 ( Optional )
#Monitor Output
# pv
# dd of=/output status=progress

#please use clear file-endings like .tar.bz2.crypt or .img.xz.crypt.
#please backup your encryption-key somewhere. Best Case offline on a sheet of Paper

##Now Create ur Command by Choosing One Command in each step and 

#sudo dd if=/dev/sdb3 | lbzip2 -9 | openssl enc -aes-256-cbc -salt -in - -out - -pass file:/home/user/enc.pw | pv > /dev/null
