# -*- coding: utf-8 -*-
# !/usr/bin/env python

"""
-------------------------------------------------
   Description :
   Author :       caiyueliang
   Date :         2020/02/21
-------------------------------------------------

"""
import os
import argparse
import time
import random


class GenUtt(object):
    def __init__(self, root_path):
        self.utt2spk = os.path.join(root_path, "utt2spk")
        self.utt2spk_sort = os.path.join(root_path, "utt2spk_sort")
        # self.utt_list = os.path.join(root_path, "utt_list")
        self.utt_list = "./utt_list"
        pass

    @staticmethod
    def read_data(file_name):
        if os.path.exists(file_name) is False:
            raise "[GenUtt][read_data][error] " + file_name + " not exist !!!"

        with open(file_name, 'r') as f:
            lines = f.readlines()
            return lines

    # 写数据 flag:'a+'
    @staticmethod
    def write_data(file_name, data, flag):
        with open(file_name, flag) as f:
            f.write(data)

    def sort_utt(self):
        cmd = "cat " + self.utt2spk + " | awk  '{print $1}' | awk  -F '-'  '{print $2\" \"$0}' | awk '{if(a[$1]){a[$1]=a[$1]\" \"$2}else{a[$1]=$2}}END{for(i in a)print a[i]}' > " + self.utt2spk_sort
        print(cmd)
        status = os.system(cmd)
        if status != 0:
            assert 0 == 1

    def gen_utt(self):
        utt_str = ""
        start_time = time.time()

        # utt2spk整理排序
        self.sort_utt()

        lines = self.read_data(self.utt2spk_sort)

        for line in lines:
            utt_list = line.strip().split(" ")
            # utt_str = utt_list[random.randint(0, len(utt_list), 1)] + "\n"
            utt_str += utt_list[random.sample(range(len(utt_list)), 1)[0]] + "\n"

        self.write_data(self.utt_list, utt_str, "w")
        print("[gen_utt] time used: ", time.time() - start_time)


def parse_argvs():
    parser = argparse.ArgumentParser(description='文件夹数据合并')
    parser.add_argument("--src_dir", help="原始数据文件夹_1")

    args = parser.parse_args()
    print('[experiment_creator] args: %s' % args)

    return parser, args


if __name__ == "__main__":
    parser, args = parse_argvs()

    gen_utt = GenUtt(args.src_dir)
    gen_utt.gen_utt()
