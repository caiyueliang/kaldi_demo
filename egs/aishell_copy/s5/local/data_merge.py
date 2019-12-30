# -*- coding: utf-8 -*-
# !/usr/bin/env python

"""
-------------------------------------------------
   Description :
   Author :       caiyueliang
   Date :         2019/12/27
-------------------------------------------------

"""
import os
import argparse


class DataMerge(object):
    def __init__(self):
        pass

    @staticmethod
    def read_data(file_name):
        if os.path.exists(file_name) is False:
            raise "[DataMerge][read_data][error] " + file_name + " not exist !!!"
        with open(file_name, 'r') as f:
            lines = f.readlines()
            return lines

    # 写数据 flag:'a+'
    @staticmethod
    def write_data(file_name, data, flag):
        with open(file_name, flag) as f:
            f.write(data)

    def _merge_two_files_into_one(self, in_file_1, in_file_2, out_file):
        data_list_1 = self.read_data(in_file_1)
        data_list_2 = self.read_data(in_file_2)

        new_dict = dict()

        for data in data_list_1:
            data_split = data.split(" ")
            if data_split[0] not in new_dict.keys():
                new_dict[data_split[0]] = data

        for data in data_list_2:
            data_split = data.split(" ")
            if data_split[0] not in new_dict.keys():
                new_dict[data_split[0]] = data

        key_list = sorted(new_dict.keys())
        for key in key_list:
            self.write_data(out_file, new_dict[key], "a+")

    def merge_1(self, src_dir_1, src_dir_2, output_dir):
        print("[DataMerge][merge_1]  src_dir_1 : ", src_dir_1)
        print("[DataMerge][merge_1]  src_dir_2 : ", src_dir_2)
        print("[DataMerge][merge_1] output_dir : ", output_dir)

        file_list = ["cmvn.scp", "feats.scp", "spk2utt", "text", "utt2spk", "wav.scp"]

        if os.path.exists(output_dir) is False:
            os.makedirs(output_dir)

        for file in file_list:
            file_1 = os.path.join(src_dir_1, file)
            file_2 = os.path.join(src_dir_2, file)
            output_file = os.path.join(output_dir, file)
            print("[DataMerge][merge_1]  file_1 : ", file_1)
            print("[DataMerge][merge_1]  file_1 : ", file_1)
            print("[DataMerge][merge_1]  output_file : ", output_file)

            if os.path.exists(output_file):
                os.remove(output_file)

            self._merge_two_files_into_one(file_1, file_2, output_file)
        return


def parse_argvs():
    parser = argparse.ArgumentParser(description='文件夹数据合并')
    parser.add_argument("--src_dir_1", help="原始数据文件夹_1")
    parser.add_argument("--src_dir_2", help="原始数据文件夹_2")
    parser.add_argument("--output_dir", help="输出数据文件夹")

    args = parser.parse_args()
    print('[experiment_creator] args: %s' % args)

    return parser, args


if __name__ == "__main__":
    parser, args = parse_argvs()

    DataMerge().merge_1(src_dir_1=args.src_dir_1, src_dir_2=args.src_dir_2, output_dir=args.output_dir)
