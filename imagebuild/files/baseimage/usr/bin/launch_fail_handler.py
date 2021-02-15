#!/usr/bin/env python
from __future__ import print_function
import pika
import json
import os, sys, time
from optparse import OptionParser
import pyslurm
message_queue_name='stopped_launches'
def encode_string ( details ):
    try:
       retstr = json.dumps ( details )
    except:
       return None
    return retstr

def decode_string ( message ):
     try:
         retdict = json.loads( message )
     except:
         return {}
     if 'waitfor' in retdict:
         retdict['waitlist'] = waitlist(retdict["waitfor"])
        
     return retdict

def open_channel(queuehost, message_queue_name):

    connection = pika.BlockingConnection(
        pika.ConnectionParameters(host=queuehost ))
    channel = connection.channel()

    channel.queue_declare(queue=message_queue_name)
    return channel

def sender ( channel, details ):
 
    print (encode_string( details) )
    channel.basic_publish(exchange='', routing_key=message_queue_name, body=encode_string( details) )
    print(encode_string( details) )
    channel.connection.close()

def callback(ch, method, properties, body):
    print(" [x] Received %r" % body)
    details = decode_string ( body )
    print ( details )
    try : 
        node = details['node']
        print ( node )
    except:
        print ("FAILED as node is not listed in message")
         
    nodes_info = get_nodes()
    
    if not node in nodes_info:
        print ("FAILED as node %s is not in the cluster" % ( node ))
        return 
    print ( node, nodes_info[node])
    ch.basic_ack(delivery_tag = method.delivery_tag)
    #now spawn a handler to wait for node before setting resume
    print ( get_node_state(node) ) #"MIXED#+CLOUD" when powering up
    if 'waitlist' not in details and 'waitfor' in details:
         wait_list = waitlist(details['waitfor']) 
    else:
          wait_list = details['waitlist']
    while get_node_state(node) not in wait_list:
         print ("%s %s" % ( str(type(get_node_state(node))) , get_node_state(node)) )
         print (get_node_state(node))
         time.sleep(3)        
    set_node_state(node, "NODE_STATE_POWER_SAVE", "waiting for job")

def get_node(node):
    nodes = get_nodes()
    if node in nodes:
         return nodes[node]
    return None
      
def get_node_state(node):
    node  = get_node(node)
    if node :
           print (node)
    else: print ("nope")
    if "state" in node:
           print ("node has a state of %s" % (state) )
           return node['state']
    else: 
       print ("node does not have a state %s" % node.keys())
    return None

def decode_state(state):
    if state.lower() == 'down' or state == "NODE_STATE_DOWN": 
        return pyslurm.NODE_STATE_DOWN
    elif state.lower() == 'resume' or state == "NODE_RESUME":
        return pyslurm.NODE_RESUME
    elif state.lower() == 'power_save' or state == "NODE_STATE_POWER_SAVE":
        return pyslurm.NODE_STATE_POWER_SAVE
    elif state.lower() == 'power_up' or state == "NODE_STATE_POWER_UP":
        return pyslurm.NODE_STATE_POWER_UP

def encode_state(pyslurm_state):
   if pyslurm_state == pyslurm.NODE_STATE_DOWN:
         return "NODE_STATE_DOWN"
   if pyslurm_state == pyslurm.NODE_STATE_POWER_SAVE:
         return "NODE_STATE_POWER_SAVE"

"""Modify the state of a Node or BG Base Partition

   Valid States :

          NODE_RESUME
          NODE_STATE_DRAIN
          NODE_STATE_COMPLETING
          NODE_STATE_NO_RESPOND
          NODE_STATE_POWER_SAVE
          NODE_STATE_FAIL
          NODE_STATE_POWER_UP

   Some states are not valid on a Blue Gene
"""
def set_node_state( nodename, state, reason ):
    STATE = decode_state(state)
    Node_dict = {
        'node_names': nodename,
        'node_state': STATE,
        'reason': reason
        }

    try:
        a = pyslurm.node()
        rc = a.update(Node_dict)
    except ValueError as e:
        print("Node Update error - {0}".format(e.args[0]))
    else:
        print("Node {0} successfully updated".format(Node_dict["node_names"]))   



def reciever(channel):
    channel.basic_consume( callback,
        queue=message_queue_name)

    print(' [*] Waiting for messages. To exit press CTRL+C')
    channel.start_consuming()

def display_nodes(node_dict):

    if node_dict:

        date_fields = [ 'boot_time', 'slurmd_start_time', 'last_update', 'reason_time' ]

        print('{0:*^80}'.format(''))
        for key, value in node_dict.items():

            print("{0} :".format(key))
            for part_key in sorted(value.items()):

                if part_key in date_fields:
                    ddate = value[part_key]
                    if ddate == 0:
                        print("\t{0:<17} : N/A".format(part_key))
                    else:
                        ddate = pyslurm.epoch2date(ddate)
                        print("\t{0:<17} : {1}".format(part_key, ddate))
                elif ('reason_uid' in part_key and value['reason'] is None):
                    print("\t{0:<17} : ".format(part_key[0]))
                else:
                    print("\t{0:<17} : {1}".format(part_key[0], part_key[1]))

            print('{0:*^80}'.format(''))

def get_jobs():
    try:
        a = pyslurm.job()
        jobs = a.get()
        return jobs
        if len(jobs) > 0:

            #display(jobs)

            print()
            print("Number of Jobs - {0}".format(len(jobs)))
            print()

            pending = a.find('job_state', 'PENDING')
            running = a.find('job_state', 'RUNNING')
            held = a.find('job_state', 'RUNNING')

            print("Number of pending jobs - {0}".format(len(pending)))
            print("Number of running jobs - {0}".format(len(running)))
            print()

            print("JobIDs in Running state - {0}".format(running))
            print("JobIDs in Pending state - {0}".format(pending))
            print()
        else:

            print("No jobs found !")
    except ValueError as e:
        print("Job query failed - {0}".format(e.args[0]))
        return []
    return jobs

def translate_hostlist ( nodestring ):
   

   cmdline = "scontrol show hostname %s" % nodestring
   return  os.popen(cmdline).readlines( )
def get_node_jobs(searchnode):
    jobs=get_jobs()
    foundjobs=[]
    for (id, j) in jobs.items():
        print ( id, j )
        for node in translate_hostlist( j['nodes'] ):
             print ("%s is node" %node)
             if node == searchnode:
                 foundjobs.append(j)
    return foundjobs

def get_nodes():
    try:
        Nodes = pyslurm.node()
        node_dict = Nodes.get()

        if len(node_dict) > 0:

            display_nodes(node_dict)            
            print()
            print("Node IDs - {0}".format(Nodes.ids()))

        else:
            print("No Nodes found !")

    except ValueError as e:
        print("Error - {0}".format(e.args[0]))
    
    return node_dict

def parseopts(args):

    parser = OptionParser()
    parser.add_option("-n", "--node", dest="node",
                  help="nodename", metavar="NODE")
    parser.add_option("-r", "--reason",
                  help="reason", dest="reason", )
    parser.add_option("-w", "--waitfor", dest="waitfor", default='DOWN|DOWN*',
                  help="wait for a state of the node before processing the message" )
    parser.add_option("-a", "--action", dest="action", 
                  help="Action to perform on the node" )
    parser.add_option("-c", "--cluster", dest="cluster", 
                  help="Cluster in which the node resides, defaults to unspecified hence slurm default", default=None )
    parser.add_option("-H", "--queuehost", dest="queuehost", 
                  help="Where the messagequeue service runs", default="localhost" )
    parser.add_option("-s", "--targetstate", dest="targetstate", 
                  help="State to set a node to (valid only for setstate)", default=None )

    (options, args) = parser.parse_args()
    return (options, args)

def test_details():
        return { 'node' : "node00",\
                'reason' : "timeout",\
                'waitfor': "DOWN|DOWN*",\
                'cluster': None}

#takes a string seperated by | and produces an array
def waitlist( string_to_decode ):
   if not string_to_decode: return []
   #is it already decoded
   if type(string_to_decode) == type([]):  return string_to_decode
   print (string_to_decode)
   return string_to_decode.split('|')

if __name__ == '__main__':
    print (get_nodes())
    get_node_jobs("compute02")
    sys.exit(1)
    if len (sys.argv) > 1:
        print ( sys.argv )
        (options, args) = parseopts( sys.argv[2:])
    else:
        parseopts([sys.argv[0], '-h' ])
        sys.exit(1)

    print (options)
    print (args)

    details = { 'node' : options.node,\
                'reason' : options.reason,\
                'waitfor': options.waitfor,\
                'cluster': options.cluster}
            

    queuehost=options.queuehost
    channel =  open_channel(queuehost, message_queue_name)
    
    if sys.argv[1] == 'sender':
        sender(channel, details )
    elif sys.argv[1] == 'reciever':
        reciever (channel )
    elif sys.argv[1] == 'setstate':
        set_node_state(options.node, options.targetstate, options.reason )
    else: 
       print( get_nodes() )
#    elif sys.argv[1] == 'queueservice':
#        start_message_queue()



