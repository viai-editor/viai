" replace Last Change Header in help.txt
:1s/|L|a|s|t| |c|h|a|n|g|e|:| |\d|\d|\d|\d| |\w|\w|\w| |\d|\d|/|L|a|s|t| |c|h|a|n|g|e|:| |2|0|2|4| |M|a|y| |2|7|/ge
" replace Version number in help.txt
:1s/|v|e|r|s|i|o|n| |\(\d|\)\+\.|\d|\.|/|v|e|r|s|i|o|n| |9|.|1|.|/ge
" replace ViAI and VIAI in help.txt with Vim and VIM, plus a space
:1s/|i|A|I|\(.*\)@\(\d\+\)/\='|i|m|' .. submatch(1) .. '@' .. (submatch(2) + 1)/e
:3s/|I|A|I|\(.*\)@\(\d\+\)/\='|I|M|' .. submatch(1) .. '@' .. (submatch(2) + 1)/e
