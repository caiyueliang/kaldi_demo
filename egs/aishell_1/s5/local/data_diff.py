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


class DataDiff(object):
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

    def get_dict(self, lexicon_file):
        lexicon_list = self.read_data(lexicon_file)
        lexicon_dict = dict()
        for lexicon in lexicon_list:
            lexicon_split = lexicon.split()
            if lexicon_split[0] not in lexicon_dict.keys():
                lexicon_dict[lexicon_split[0]] = 1
            else:
                lexicon_dict[lexicon_split[0]] += 1
        return lexicon_dict

    def get_diff(self, lexicon_dict, trans_file, output_file):
        trans_list = self.read_data(trans_file)
        diff_count = 0
        for trans in trans_list:
            trans_split = trans.split()
            for i in range(len(trans_split)):
                if i != 0:
                    if trans_split[i] not in lexicon_dict.keys():
                        # print("[get_diff] diff: ", trans_split[i])
                        diff_count += 1
                        self.write_data(output_file, trans_split[i] + "\n", "a+")

        print("[get_diff] total diff: ", diff_count)

    def diff(self, trans_file, lexicon_file, output_file):
        print("[DataMerge][merge_1]   trans_file : ", trans_file)
        print("[DataMerge][merge_1] lexicon_file : ", lexicon_file)

        # if os.path.exists(output_dir) is False:
        #     os.makedirs(output_dir)
        lexicon_dict = self.get_dict(lexicon_file)
        print("[diff] lexicon_dict len: ", len(lexicon_dict.keys()))

        # # 查看重复的出现的词
        # for key in lexicon_dict.keys():
        #     if lexicon_dict[key] > 1:
        #         print("[diff] key : ", key)

        self.get_diff(lexicon_dict, trans_file, output_file)
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
    # parser, args = parse_argvs()

    # trans_file = "/home/rd/caiyueliang/data/AISHELL/data_aishell/transcript_merge_aidatatang/aishell_transcript_v0.8.txt"
    trans_file = "/home/rd/caiyueliang/data/AISHELL/data_aishell/transcript_merge/aishell_transcript_v0.8.txt"

    # lexicon_file = "/home/rd/caiyueliang/data/AISHELL/resource_aidatatang_merge/lexicon.txt"
    lexicon_file = "/home/rd/caiyueliang/data/AISHELL/resource_aishell_merge/lexicon.txt"
    output_file = "./diff.txt"
    DataDiff().diff(trans_file=trans_file, lexicon_file=lexicon_file, output_file=output_file)
