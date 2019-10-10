#!/bin/bash
#########################################################################
# File Name: convert_lcd_code.sh
# Author: Edward.Tang
# mail:   @163.com
# Created Time: Fri 11 Jan 2019 04:03:39 PM CST
#########################################################################
script=`basename $0`
GREEN='\e[1;32m'
RED='\e[1;31m'
END='\e[0m'

RED()
{
	echo -e  "${RED}$*${END}"
}

GREEN()
{
	echo -e  "${GREEN}$*${END}"
}

error()
{
    echo -e  "${RED}$*${END}"
    exit 1
}

get_args()
{
    HEAD=
    IC=
    TYPE=2
    outfile=lcd.c

    if [[ $# = 0 ]]; then
        usage
        exit 1
    fi

    if ARGS=`getopt -o t:i:h -l help -- $@`;then
        echo ARGS="$ARGS"
        eval set -- "${ARGS}"
    else
        RED please confirm the filename without space.
        usage
        exit 1
    fi
    while [ "$1" ];
    do
        opt=$1
        case $opt in
            -t)
                shift
                TYPE=$1
                ;;
            -i)
                shift
                IC=$1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                error "Error: invaild argument: $opt"
                ;;
        esac
        shift
    done
    GREEN all parameters: $@

    if [ -e "$1" ]; then
        inputfile="$1"
    else
        RED inputfile "$1" is not exist, please confirm the filename without space.
        usage
        exit 1
    fi

    if [ -n "$2" ]; then
        outfile=$2
    fi

    if [ -z "$IC" ]; then
        read HEAD <"$inputfile"
        # GREEN HEAD="$HEAD"
        if [[ $HEAD =~ 'JD' ]]; then
            IC=jd
        elif [[ $HEAD =~ 'NT' ]]; then
            IC=nt
        else
            RED "Error: Unrecognizable IC Model from $inputfile."
            RED "Please specify the ic model by -i <model>."
            usage
            exit 1
        fi
    fi

    GREEN "inputfile: $inputfile"
    GREEN "outfile:   $outfile"
    GREEN "IC:  $IC"
    GREEN "TYPE=$TYPE"
}

conv_jd_type1()
{
	# cat "${inputfile}" | while read line
	# do
		# reg=`echo $line | sed -n -r '
        # s/^\s*\|\s*$//g
        # /^SSD_Single.*/{s/^.*0x(.*),0x(.*)\);/0x\2\11500/p}'`
		# if [ -n "$reg" ];then
			# echo "data_array[0] = ${reg};"
			# echo "dsi_set_cmdq(data_array, 1, 1);"
			# echo "MDELAY(1);"
		# else
			# echo $line
		# fi
	# done
    sed -r '
        s/^\s*\|\s*$//g
        /^SSD_Single.*/{
			s/^.*0x(.*),0x(.*)\);/0x\2\11500/;
            s/^(0x[a-fA-F0-9]*)/    data_array[0] = \1;/g;
			# a\dsi_set_cmdq(data_array, 1, 1);\nMDELAY(1);
            a\    dsi_set_cmdq(data_array, 1, 1);
		}
        /^SSD_CMD.*/{
			s/^.*0x(.*)\);/0x00\10500/;
            s/^(0x[a-fA-F0-9]*)/    data_array[0] = \1;/g;
			# a\dsi_set_cmdq(data_array, 1, 1);\nMDELAY(1);
            a\    dsi_set_cmdq(data_array, 1, 1);
        }
        /^Delayms.*/s/Delayms/    MDELAY/
    ' < "${inputfile}"
}

conv_jd_type2()
{
	# cat "${inputfile}" | while read line
	# do
		# reg=`echo $line | sed -n -r '/^SSD_Single.*/{s/^.*0x(.*),0x(.*)\);/\{0x\2, 1, \1\}/p}'`
		# if [ -n "$reg" ];then
			# echo $reg
		# fi
	# done
    sed -n -r '
    s/^\s*\|\s*$//g
    /^SSD_Single.*/{
        s/^.*(0x.*),(0x.*)\);/    \{\1, 1, \{\2\}\ },/p
    }
    /^SSD_CMD.*/{
        s/^.*(0x.*)\);/    \{\1, 0, \{\}\ },/p
    }' < "${inputfile}"
}

conv_nt_type1()
{
    awk -F, '
    $1 ~ /REGW|regw/{
        gsub(/REGW|regw|[[:space:]]|\/\/.*/,"");
        # print "NF=" NF
        # print "$0=" $0
        if(NF <= 2)
        {
            cmd1 = strtonum($1); cmd2 = strtonum($2);
            printf("    data_array[0] = 0x%02X%02X%d500;\n", cmd2, cmd1, NF-1)
            printf("    dsi_set_cmdq(data_array, 1, 1);\n")
        }
        else
        {
            lines = int(NF/4) + 1;
            if(NF%4 == 0)
            {
                # print "NF is a multiple of 4"
                lines--;
            }
            # print "lines=" lines
            printf("    data_array[0] = 0x%04x3902;\n", NF)
            for(row = 0; row < lines; row++)
            {
                i = row * 4; # print "i=" i;
                cmd1 = strtonum($(i + 1)); cmd2 = strtonum($(i + 2));
                cmd3 = strtonum($(i + 3)); cmd4 = strtonum($(i + 4));
                printf("    data_array[%d] = 0x%02X%02X%02X%02X;\n",
                    row+1, cmd4, cmd3, cmd2, cmd1)
            }
            printf("    dsi_set_cmdq(data_array, %d, 1);\n", lines + 1)
        }
        printf "    MDELAY(1);\n\n"
    }' < "${inputfile}"
}

conv_nt_type2()
{
    awk -F, '
    $1 ~ /REGW|regw/{
        gsub(/REGW|regw|[[:space:]]|\/\/.*/,"");
        printf("    {%s, %d, {", $1, NF-1);
        for(i = 2; i < NF; i++)
        {
            printf ("%s, ", $i)
        }
        printf("%s} },\n", $i)
    }' < "${inputfile}"
}

process_jd()
{
    case $TYPE in
        1)
        conv_jd_type1
        ;;
        2)
        conv_jd_type2
        ;;
        *)
        RED IC $IC type $TYPE is not supported.
        exit 1
        ;;
    esac
}

process_nt()
{
    case $TYPE in
        1)
        conv_nt_type1
        ;;
        2)
        conv_nt_type2
        ;;
        *)
        RED IC $IC type $TYPE is not supported.
        exit 1
        ;;
    esac
}

usage()
{
	cat <<EOF
    Convert lcd init code of vendor to mtk lcm code. Default output file is lcd.c

SYNOPSIS
${script} [OPTION] <inputfile> [outputfile]

Example: ${script} input.txt
        or
        ${script} input.txt -t1 -i jd

OPTIONS
    -t
        type: 1 or 2, default value is 2
        1 for dsi_set_cmdq function
        2 for push_table function

    -i
        IC Model: jd or nt, default value is jd
        jd for JD936xx ic
        nt for NT355xx ic

    -h
        See usage.
EOF
}

main()
{
    get_args $@
    echo ==========================================================================
    echo -e "Start converting.\n"
    case $IC in
        jd)
        process_jd | tee "$outfile"
        ;;
        nt)
        process_nt | tee "$outfile"
        ;;
        *)
        RED Error: IC $IC is not supported.
        usage
        ;;
    esac
    echo
    echo ==========================================================================
    GREEN HEAD=$HEAD
    GREEN "inputfile: $inputfile"
    GREEN "outfile:   $outfile"
    GREEN "IC:  $IC"
    GREEN "TYPE=$TYPE"
    GREEN Convert completed successfully.
    echo ==========================================================================
}

main $@

