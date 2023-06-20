global _start       ;deklaracja dla linkera
;;funkcje systemowe
SYS_READ equ 0
SYS_WRITE equ 1
SYS_OPEN equ 2
SYS_CLOSE equ 3
SYS_EXIT equ 60
;;parametry flags przy otwieraniu pliku
O_CREAT equ 64
O_EXCL equ 128
O_WRONLY equ 1
O_READONLY equ 0

buffer_len equ 1024 ;dlugosc bufora
;dlugosc bufora jest taka, bo to rozmiar strony w pamieci komputerowej

section .bss 
    ;;bufory wejsciowy i wyjsciowe i pomocniczy
    buffer_in: resb buffer_len
    buffer_out: resb buffer_len + 8 ;+8 bajtow na zapas przy przepelnieniu bufora
	
section .text
_start:
    mov rax, [rsp]      ;[rsp] - ilosc argumentow z cmd-line'a
    cmp rax, 3          ;chcemy zeby byly 3 argumenty
    jne exit_1          ;zla ilosc argumentow - exit z kodem bledu 1

;;otwieranie pliku in_file do odczytu, zwraca deskryptor pliku w rax
    mov rax, SYS_OPEN
    mov rdi, [rsp + 16]     ;[rsp + 16] - in_file
    mov  rsi, O_READONLY    ;otwieramy z flaga do odczytu
    syscall
    cmp rax, 0              ;czy blad otwarcia pliku
    jl exit_1               ;blad - exit z kodem 1
    mov r8, rax             ;r8 - deskryptor pliku in_file

;;tworzenie pliku out_file, zwraca deskryptor pliku w rax
    mov rax, SYS_OPEN
    mov rdi, [rsp + 24]                 ;[rsp + 24] - out_file
    mov rsi, O_CREAT+O_EXCL+O_WRONLY    ;flagi 
    mov rdx, 0644o                      ;uprawnienia do pliku, 'o' bo ósemkowy
    syscall
    mov r9, rax                         ;r8 - deskryptor pliku out_file
    cmp rax,0                           ;czy blad tworzenia pliku
    jge main                            ;nie ma bledu -  main
    mov rdi, r8                         ;obsluga bledu tworzenia pliku:  
    call close_file                     ;-zamkniecie pliku in_file
    jmp exit_1                          ;-wyjscie z kodem 1
    
;;iteracja przez in_file i zapisywanie do out_file
main: 
    xor r12, r12            ;r12 - iterator do bufora wyjsciowego
    xor r15, r15            ;r15 - ilosc bajtow w najdluzszym ciagu bez s/S 
main_loop: 
    xor r13, r13            ;r13 - licznik petli do czytania z bufora wejsciowego
    call read_in_file       ;w rax - ilosc odczytanych znakow
    mov r10, rax            ;r10 - ilosc odczytanych znakow 
    cmp r10, 0              ;czy koniec pliku
    je main_loop_exit       ;koniec pliku      
buffer_loop:
    cmp r12, buffer_len         ;czy przepelnienie bufora wyjsciowego
    jge save_to_file            ;bufor wyjsciowy przepelniony
    cmp r13, r10                ;czy licznik == ilosc_pobranych znakow z bufora
    jge main_loop               ;wszystkie znaki w bufora odczytane
    mov r14b, [buffer_in+r13]   ;r14b - zawartosc aktualnie sprawdzanego znaku
    cmp r14b, 's'               ;czy wczytany znak to s/S
    je write_s_S
    cmp r14b, 'S'               
    je write_s_S
    inc r13                     ;licznik buf. wejsciowego ++
    inc r15                     ;(ilosc bajtow w ciagu z innymi znakami niz s/S)++
    jmp buffer_loop
main_loop_exit:
    call write_num
	cmp r12, 0              ;czy bufor wyjsciowy jest pusty
	je main_loop_exit_next  ;tak - jmp do wyjscia z funkcji
	mov rdx, r12            ;r12 - ilosc skumulowanych znakow w buf. wyjsciowym
	call write_out_file     ;zapis do pliku
main_loop_exit_next:
    call close_files        ;zamykamy pliki in/out file
    call exit_0             ;exit z kodem 0

;;odczyt pliku in_file
read_in_file:
    mov rax, SYS_READ
    mov rdi, r8             ;r8 - deksryptor in_file
    mov rsi, buffer_in
    mov rdx, buffer_len
    syscall
    cmp rax, 0              ;czy blad odczytu 
    jge read_in_file_ret    ;brak bladu odczytu
    call close_files_exit_1 ;obsługa bledu odczytu 
read_in_file_ret:
    ret

;;buf. wyjsciowiowy przepelniony - zapis do pliku out_file
save_to_file:
    mov rdx, r12            ;ilosc skumulowanych znakow w buf. wyjsciowym
    call write_out_file     ;zapis do pliku
    xor r12, r12            ;zerujemy iterator bufora wyjsciowego
    jmp buffer_loop

;;zapis pliku out_file
;w rdx podaj ilosc znakow do zapisu przed wywolaniem tej funkcji
write_out_file:
    cmp rdx, 0              ;buf. wyjsciowy pusty 
    je write_out_file_ret   ;tak - wyjdz z funkcji
    mov rax, SYS_WRITE      ;wpisywanie znakow z buf. wyjsciowego do pliku 
    mov rdi, r9
    mov rsi, buffer_out
    syscall
    cmp rax, 0              ;czy blad  
    jl close_files_exit_1   ;obsluga bledu odczytu
    sub rdx, rax            ;nie - od ilosci znakow w buforze odejmij tyle ile wpisano do pliku
    jmp write_out_file      
write_out_file_ret:
    ret

;;zapis do buf. wyjsciowego dlugosci niepustego ciagu bez s/S i znaku s/S
write_s_S:
    call write_num
    mov [buffer_out+r12], r14b      ;do buf. wyjsciowego zapisz akt. znak (s/S)
    inc r12                         ;iterator buf. wyjsciowego ++
    inc r13                         ;licznik buf. wejsciowego ++
    xor r15,r15                     ;zerujemy ilosc bajtow innych znakow niz s/S
    jmp buffer_loop
write_num: 
    cmp r15, 0                      ;czy nazbieraly sie inne znaki niz s/S
    je write_num_ret                ;nie - ret
    mov [buffer_out + r12], r15w    ;tak - zapisujemy ilosc ich bajtow do bufora w little-endian
    add r12, 2                      ;iterator buf. wyjsciowego += 2
write_num_ret:
    ret	

;;gdy wystapi blad - zamkniecie plikow i zakonczenie programu z kodem 1
close_files_exit_1:
    call close_files
    call exit_1

;;zamykanie plikow in/out file
close_files: 
    xor r10, r10        ;w r10 - info o bledzie SYS_CLOSE, 0 - nie bylo, < 0 byl
    mov rdi, r8         ;zamykanie pliku in_file
    call close_file
    cmp rax, 0  
    jl close_file_error ;zrob: r10 < 0 jesli blad
close_files_next:    
    mov rdi, r9         ;zamykanie pliku out_file
    call close_file
    add rax, r10
    cmp rax, 0          ;czy byl blad zamkniecia ktoregos plikow in/out file 
    jl exit_1           ;tak - wyjscie z funkcji z kodem 1
    ret                 ;nie - powrot z funkcji close_files
close_file:
    mov rax, SYS_CLOSE
    syscall
    ret
close_file_error:
    mov r10, -1
    jmp close_files_next

;;wyjscie z programu z odpowiednimi kodami
exit_0: 
    mov rdi, 0
    jmp exit_function	
exit_1:
    mov rdi, 1
exit_function: 
    mov rax, SYS_EXIT
    syscall

