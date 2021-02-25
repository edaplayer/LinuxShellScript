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
    outfile=lcd_table.c

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
        RED inputfile "$1" is not exist, please confirm the filename.
        usage
        exit 1
    fi

    if [ -n "$2" ]; then
        outfile=$2
    fi

    if [ -z "$IC" ]; then
        IC=jd
    fi

    GREEN "inputfile: $inputfile"
    GREEN "outfile:   $outfile"
    GREEN "IC:  $IC"
}

conv_jd_dsi()
{
    awk -F, -v OFS=", " '
    /SSD_Single/{
        gsub(/SSD_Single|[();]|\s*|\/\/.*/, "", $0);
        data0 = strtonum($1)
        data1 = strtonum($2)

        printf("    data_array[0] = 0x%02X%02X1500;\n", data1, data0)
        printf("    dsi_set_cmdq(data_array, 1, 1);\n")
        next
    }

    /SSD_CMD/{
        gsub(/SSD_CMD|[();]|\s*|\/\/.*/, "", $0);
        cmd = strtonum($1)
        printf("    data_array[0] = 0x00%2X0500;\n", cmd)
        printf("    dsi_set_cmdq(data_array, 1, 1);\n")
        next
    }

    /Delayms/{
        gsub(/Delayms/, "    MDELAY", $0);
    }
    1 ' < "${inputfile}"
}

conv_jd_table()
{
    awk -F, '
    /SSD_Single/{
        match($0, "(//.*)", comment)

        gsub(/SSD_Single|[();]|\s*|\/\/.*/, "", $0);

        data0 = strtonum($1)
        data1 = strtonum($2)
        printf("    {0x%02X, 1, {0x%02X} },%s\n", data0, data1, comment[1])
        next
    }

    /SSD_CMD/{
        match($0, "(//.*)", comment)
        gsub(/SSD_CMD|[();]|\s*|\/\/.*/, "", $0);
        data0 = strtonum($1)
        printf("    {0x%02X, 0, {} },%s\n", data0, comment[1])
        next
    }
    # 1 ' < "${inputfile}"
}

conv_nt_dsi()
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

conv_nt_table()
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

conv_hx_dsi()
{
    awk '
    {
        gsub(/0x/, "");
        cmd = $1
        data = $2
        printf("    data_array[0] = 0x%s%s1500;\n", data, cmd);
        printf("    dsi_set_cmdq(data_array, 1, 1);\n");
    }' < "${inputfile}"
}

conv_ota_table()
{
    sed -n -r '
    s/^\s*\|\s*$//g
    /^W_COM.*/{
        s/^.*(0x.*),(0x.*)\);/    \{\1, 1, \{\2\}\ },/p
    }' < "${inputfile}"
}

conv_ili_table()
{
    awk -F, '
    $1 ~ /REGISTER/{
        gsub(/REGISTER,|[[:space:]]|\/\/.*/,"");
        printf("    {0x%s, %d, {", $1, $2);
        for (i = 3; i < NF; i++) {
            printf ("0x%s, ", $i)
        }
        if ($i != "") {
            printf("0x%s", $i)
        }
        printf("} },\n", $i)
    }' < "${inputfile}"
}

conv_boe_table()
{
    awk -F= '
    $0 ~ /=/{
        gsub(/REGISTER,|[[:space:]]|\/\/.*/,"");
        printf("    {0x%s, 1, {0x%s} },\n", $1, $2);
    }' < "${inputfile}"
}

conv_table_to_dsi()
{
    awk -F, -v OFS="," '
    /{.*}/{
        gsub(/{|}|[[:space:]]|\/\/.*/,"");

        len = $2 + 1
        $2=""
        sub(",,", ",", $0);

        if(len <= 2)
        {
            cmd1 = strtonum($1); cmd2 = strtonum($2);
            printf("    data_array[0] = 0x%02X%02X%d500;\n", cmd2, cmd1, len-1)
            printf("    dsi_set_cmdq(data_array, 1, 1);\n")
        }
        else
        {
            lines = int(len/4) + 1;
            if(len%4 == 0)
            {
                # print "len is a multiple of 4"
                lines--;
            }
            # print "lines=" lines
            printf("    data_array[0] = 0x%04x3902;\n", len)
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
    }' < "${1}"
}

process_jd()
{
    conv_jd_table | tee lcd_table.c
    conv_jd_dsi | tee lcd_dsi.c
    cp lcd_dsi.c lcd_dsi_jd.c
}

process_nt()
{
    conv_nt_dsi | tee lcd_dsi.c
    conv_nt_table | tee lcd_table.c
    cp lcd_dsi.c lcd_dsi_nt.c
}

process_hx()
{
    conv_hx_dsi | tee lcd_dsi.c
}

process_ota()
{
    conv_ota_table | tee lcd_table.c
}

process_ili()
{
    conv_ili_table | tee lcd_table.c
}

process_boe()
{
    conv_boe_table | tee lcd_table.c
}

usage()
{
	cat <<EOF
    Convert lcd init code of vendor to mtk lcm code. Default output file is lcd.c
    Output file is lcd_dsi.c and lcd_table.c

SYNOPSIS
${script} [OPTION] <inputfile> [outputfile]

Example: ${script} input.txt
        or
        ${script} input.txt -t1 -i jd

OPTIONS
    -i
        IC Model: jd or nt, default value is jd
        jd for JD936xx ic(Fitipower)
        nt for NT355xx ic(novatek)
        hx for HX82xx ic(himax)
        ota for ota7290b ic
        ili for ili9881 ic
        boe for nt51021(boe) ic

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
        process_jd
        ;;
        nt)
        process_nt
        ;;
        hx)
        process_hx
        ;;
        ota)
        process_ota
        ;;
        ili)
        process_ili
        ;;
        boe)
        process_boe
        ;;
        *)
        RED Error: IC $IC is not supported.
        usage
        ;;
    esac

    conv_table_to_dsi lcd_table.c | tee lcd_dsi.c

    echo
    echo ==========================================================================
    GREEN HEAD=$HEAD
    GREEN "inputfile: $inputfile"
    GREEN "outfile:   $outfile"
    GREEN "IC:  $IC"
    GREEN Convert completed successfully.
    echo ==========================================================================
}

main $@

