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


class DictMerge(object):
    def __init__(self):
        pass

    @staticmethod
    def read_data(file_name):
        if os.path.exists(file_name) is False:
            raise "[DictMerge][read_data][error] " + file_name + " not exist !!!"
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

        for data in data_list_1:
            self.write_data(out_file, data, "a+")
        for data in data_list_2:
            self.write_data(out_file, data, "a+")

    def list_to_dict(self, data_list):
        new_dict = dict()
        for data in data_list:
            # print(data)
            data_split = data.split(" ")
            if data_split[0] not in new_dict.keys():
                new_dict[data_split[0]] = data
            # if data_split[0] in new_dict.keys():
            #     print(new_dict[data_split[0]])
            #     print(data)
            # else:
            #     new_dict[data_split[0]] = data
        return new_dict

    def _merge_two_files_into_one_unique(self, in_file_1, in_file_2, out_file):
        data_list_1 = self.read_data(in_file_1)
        print("[DictMerge] data_list_1 len : ", len(data_list_1))
        data_dict_1 = self.list_to_dict(data_list_1)
        print("[DictMerge] data_dict_1 len : ", len(data_dict_1))

        data_list_2 = self.read_data(in_file_2)
        print("[DictMerge] data_list_2 len : ", len(data_list_2))
        data_dict_2 = self.list_to_dict(data_list_2)
        print("[DictMerge] data_dict_2 len : ", len(data_dict_2))

        new_list = list()

        for key_1, value_1 in data_dict_1.items():
            if key_1 in data_dict_2.keys():
                data_dict_2.pop(key_1)
                new_list.append(value_1)
            else:
                new_list.append(value_1)

        print("[DictMerge] new_list len : ", len(new_list))
        print("[DictMerge] data_dict_2 del len : ", len(data_dict_2))
        for key_2, value_2 in data_dict_2.items():
            new_list.append(value_2)
        print("[DictMerge] new_list len : ", len(new_list))

        for data in new_list:
            # print(data)
            self.write_data(out_file, data, "a+")

    # def _merge_two_files_into_one_unique(self, in_file_1, in_file_2, out_file):
    #     data_list_1 = self.read_data(in_file_1)
    #     data_list_2 = self.read_data(in_file_2)
    #     print("[DictMerge] data_list_1 len : ", len(data_list_1))
    #     print("[DictMerge] data_list_2 len : ", len(data_list_2))
    #
    #     new_list = list()
    #     diff_count = 0
    #
    #     for data_1 in data_list_1:
    #         # print(data)
    #         data_1_split = data_1.split(" ")
    #         del_data_2 = None
    #         found = False
    #         for data_2 in data_list_2:
    #             data_2_split = data_2.split(" ")
    #
    #             if data_1_split[0] == data_2_split[0]:
    #                 # print(data_1_split[0])
    #
    #                 if data_1 != data_2:
    #                     # print(data_1)
    #                     # print(data_2)
    #                     diff_count += 1
    #
    #                 del_data_2 = data_2
    #                 found = True
    #                 break
    #
    #         if found is True:
    #             data_list_2.remove(del_data_2)
    #             new_list.append(data_1)
    #         else:
    #             new_list.append(data_1)
    #
    #     print("[DictMerge] diff_count len : ", diff_count)
    #     print("[DictMerge] new_list len : ", len(new_list))
    #     print("[DictMerge] data_list_2 del len : ", len(data_list_2))
    #     for data_2 in data_list_2:
    #         new_list.append(data_2)
    #     print("[DictMerge] new_list len : ", len(new_list))
    #
    #     for data in new_list:
    #         # print(data)
    #         self.write_data(out_file, data, "a+")

    def merge_1(self, src_dir_1, src_dir_2, output_dir):
        print("[DictMerge][merge_1]  src_dir_1 : ", src_dir_1)
        print("[DictMerge][merge_1]  src_dir_2 : ", src_dir_2)
        print("[DictMerge][merge_1] output_dir : ", output_dir)

        file_list = ["lexiconp.txt", "lexicon.txt"]

        if os.path.exists(output_dir) is False:
            os.makedirs(output_dir)

        for file in file_list:
            file_1 = os.path.join(src_dir_1, file)
            file_2 = os.path.join(src_dir_2, file)
            output_file = os.path.join(output_dir, file)
            print("[DictMerge][merge_1]  file_1 : ", file_1)
            print("[DictMerge][merge_1]  file_1 : ", file_1)
            print("[DictMerge][merge_1]  output_file : ", output_file)

            if os.path.exists(output_file):
                os.remove(output_file)

            self._merge_two_files_into_one_unique(file_1, file_2, output_file)
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

    DictMerge().merge_1(src_dir_1=args.src_dir_1, src_dir_2=args.src_dir_2, output_dir=args.output_dir)
