from chef import autoconfigure, Node,Search,ChefAPI
import pandas as pd
from tkinter import *
from pandastable import Table, TableModel

api = autoconfigure()
chefserver = '<chef-server>'
userkey = '<username.pem>'
username ='<username>'

chefapiobject = ChefAPI(chefserver, userkey, username)


# set the rows to higher value if you have more nodes in Chef
results = Search('node','*',rows=4000,api=chefapiobject)   
df = pd.DataFrame()

#
array = []
for node in results:
    if 'azure' in node['automatic'].keys():     
        if node['automatic']['azure']['metadata'] is not None :
            loc = "Azure - " + node['automatic']['azure']['metadata']['compute']['location']
    else:        
        loc = "OnPremise"

    if len(node['run_list']) !=0:
        node_runlist = node['run_list']
        env = node['chef_environment']
        node_runlist.sort()
        node_row = [node['name'],env,loc,*node_runlist]
        array.append(node_row)
    else:
        node_runlist = []
        env = node['chef_environment']
        node_row = [node['name'],env,loc,*node_runlist]
        array.append(node_row)
        
        
        
df = pd.DataFrame(array)          
print("Total no. of nodes: " + str(len(results)))



class WinApp(Frame):
        """Basic frame for the table"""
        def __init__(self, parent=None):
            self.parent = parent
            Frame.__init__(self)
            self.main = self.master
            self.main.geometry('600x400+200+100')
            self.main.title('Chef node runlist')
            f = Frame(self.main)
            f.pack(fill=BOTH,expand=1)
            self.table = pt = Table(f, dataframe=df,showtoolbar=True, showstatusbar=True)
            pt.show()
            return


if __name__ == '__main__':
    app = WinApp()
    #launch the app
    app.mainloop()