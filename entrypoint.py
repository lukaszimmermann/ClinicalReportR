#!/usr/bin/env python3
import sys
import argparse
import os
import subprocess


def get_vcf_file_extension():
    return "vcf"

def get_annotated_substring():
    return "annotated"

def is_annotated(filename):
    return get_annotated_substring() in filename

def exit_if(test, msg, exit=0):
    
    if test:
        if exit == 0:
            print(msg)
        else:
            print("FATAL: " + msg, file=sys.stderr)
        sys.exit(exit)


def remove_if_exists(filename):
    if (os.path.exists(filename)):
        os.remove(filename)

def list_unannotated_vcf_files(d):
    """
    Lists the absolute paths of all vcf files in the specified directory d
    """
    return [ os.path.join(d, x) for x in os.listdir(d)  if x.endswith(get_vcf_file_extension()) and not is_annotated(x)]

def remove_extension(file_path):
    """
    Chops the file extensions from all files in the list
    """
    return '.'.join(file_path.split('.')[:-1]) 


################################################################################################


def process(*commands):
    print("Executing: " + ' '.join(commands))

    my_env = os.environ.copy()
    my_env["PERL5PATH"] = "/opt/vep/.vep/Plugins/loftee-0.3-beta:"
    process = subprocess.Popen(commands, env=my_env)
    process.communicate()
    return process.wait()
  

def prepare_in_out(basename, input_extension, output_extension):

    input_file = basename + "." + input_extension
    output_file  = basename + "." + output_extension
    remove_if_exists(output_file)
    exit_if(not os.path.exists(input_file), "Input file does not exist", 2)

    return (input_file, output_file)


def print_sep1():
    print("#############################################################") 


def print_sep2():
    print("-----------------------------------------------------")


def main(argv):


    vcf_files_dir = '/inout'
    print("Looking for VCF files in the following container directory: {}".format(vcf_files_dir))    
    vcf_files = list_unannotated_vcf_files(vcf_files_dir)
  
    print_sep1()
    print("Processing the following files: ")
    print_sep2()
    for vcf_file in vcf_files:
        print(vcf_file)
    print_sep1()

    # Process each of the files in turn
    for vcf_file in vcf_files:
       print("Processing: {}".format(vcf_file))       
       base_name = remove_extension(vcf_file)

       # Step: VCF
       (inpt, out) = prepare_in_out(base_name, 'vcf', 'annotated.vcf')
       result = process('/opt/vep/src/ensembl-vep/vep', '-i', inpt, '-o', out, '--config', '/opt/vep.ini')
        
       # Step: Generation of data for report
       (inpt, out) = prepare_in_out(base_name, 'annotated.vcf', 'json')
       result = process("Rscript",
                        "--no-save",
                        "--no-restore",
                        "--no-init-file",
                        "--no-site-file",
                        "/opt/reporting/reporting.R", "-f", inpt, "-r", out)
    
       # Step: Reporting:
       (inpt, out) = prepare_in_out(base_name, 'json', 'docx')
       result = process("/usr/bin/nodejs",
                        "/opt/templater/main.js",
                        "-d", inpt, 
                        "-t", "/opt/templater/data/template.docx",
                        "-o",  out)
       print_sep2()

if __name__ == '__main__':
    main(sys.argv)


