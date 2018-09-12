# t
A BASH to-do list manager and simple project planner
----------------------------------------------------

I'm fed up using the Git README file as a rough todo list and the manual sorting, marking as done
and other project planning things I do when working on code and configs etc.

Yes I know I could use github issues but I tend to always work in terminal and don't like to 
switch between keyboard and mouse all the time. And of course, when an idea comes its best to 
get it recorded ASAP.

Inspired by https://github.com/sjl/t but done in BASH as I don't like Python and need something with no Python dependencies. This is even simplier than the other one and like the other, the data file is in pure ASCII so it can also be edited directly and added to your version control. Not 100% certain about multi-user, there is some file locking in place so it might be safe to use :-)




New Feature!
------------

I've decided to add somekind of task sync from the command line to multi-lists, and then to expand that to integrate with other
todo list services which will then keep all my lists in one easy to use form. Perhaps, if you're lucky then it might work for you too.

The server side is at https://mytodos.besbox.com. You can visit there and register an account. 

So far we can sync between 't' clients and handle soft deletes. Next up isthe really cool features of syncing with other todo list systems. I will be going with Google Tasks and Checkvist to start with as those are the two that I use elsewhere at the moment. If you have a different one let me know!




td.sh
-----

A new quick and dirty dialogs view of the list with some editing. Just playing at the moment. :-)


Command Line
------------



```bash
Command line options:

t <options> 



<tid> [<tid> <tid>.. ] Will mark as done. If an email is set then send a email to that user

s                      Sort by item name (unless dependencies are present)
-a                     When marking as done send to archive (default enabled)
-A                     When marking as done disable send to archive
-c <category> <tid>    Add a category
-C                     Collapse nested tasks
-d <tid> <text>        When adding put as dependant on another task
-D <tid> <date>        Set a due date on the line using any format that 'date' can handle
-e <tid> <email>       Add an email address to an item. If you complete a task an email will be sent to that
                       address using the default sender, if you have T_SENDER set then this will be used instead.
-f <string>            Display todo list with a case sensitive filter 
-H <colour>            Set a colour highlight on the line(s) (1-8)
-i                     Ignore T_TODO variable and use defaults
-m <newtid> <tid>      Move <tid> to be at line <newtid>
-n <tid> <note>        Add a note to the item (if text starts with a plus then add another line)
-p <prio> <tid>        Set priority mark on a task or list of tasks
-P <flags>             Set the todo list's property display comma delited flags when listing items:

			CREATEDATE
			USER
			TAG
			PRIO
			CATEGORY
			MARKCOM
			ARCHIVED
			NOTE
			IND  	Show indicator for presence of notes (+), email (@), a % is shown for work tracking, has a due date (!) and if overdue (!!)
			DUE
			ESTTIME
			WORKED
			PERCENT
			TRIGGER
			EMAIL

			If enviromental var T_DISPLAY is set with above, this will over ride the default

			Defaults to TAG,PRIO,MARKCOM,IND


			T_TODO var can be given to specify a non-standard todo list.

-s <flag>              Temp sort by the applied flag
-t <tag> <tid>         Add a tag to a task or list of tasks
-u <tid>               Unmark task or list of tasks

Project Planning Switches:

-E <unit> <tid>        Estimate of time to complete. Unit can mean anything, just be consistent
-W <unit> <tid>        Record a unit of work against a task.
-g                     Display list with Gannt display

Task Sync Switches:
-------------------

-h                     Shows help and summary of lists present
-l <tid> [<list name>] Assign task to a list called <list name>. 
                       If <list name> is empty then uses current list
-l                     Display task list with a summary of list names at the end
-L <list name>         Switch task display to <list name>
-L                     Switch task display to all lists
-z                     Full sync of tasks
-z                     Full sync of tasks (plus purge of soft deleted items)

To add a line:
	
t <text>
```

An example of some of the features (many more if you use the -h switch)

To add an item to the todo list
-------------------------------

t Add an item to my todo list

To list everything in the current todo list
-------------------------------------------

t

To mark an item as done
-----------------------

t [item nos]

Where [item nos] is a single number or a space delimited list. Can be used to mark or apply any of the flags below.

e.g. 

	t 12
	t 1 2 7 10

To delete a marked done item 
----------------------------

t [item no a 2nd time]

If give with -a then instead of deleting move the completed line to todo-archive.txt

To unmark as done
-----------------

t -u [item nos] 


To add dependancy 
-----------------

t -d [item no] [text]

To add a numeric priority number
--------------------------------

t -p [prio] [item nos]

To add a tag to a line
----------------------

t -t [tag] [item nos]

To sort the list
----------------

t s

To add notes
------------

t -n [item no] [note text]


Other Features
--------------

* Handy thing to do from this other one is to add the number of items in the todo list to your prompt:

export PS1='[$(t | wc -l | sed -e"s/ *//")]'" $PS1"

* Another useful one is to provide a quick display change. For example if you wanted to only view the items that have notes and to expand them fully you could do:

alias tn="T_DISPLAY=NOTES t -f +"

That will display only the notes property and filter on the '+' symbol which if you use the default IND display flag will be on all of the notes rows (plus a few others but at least you mostly get the notes)


* If you want to have multiple lists for different things you can override the default todo list name and location with the T_TODO variable:

alias tf="T_TODO=~/todo-foodshop t"


* To list all items that have a due date

alias td="T_DISPLAY=DUE t -f !"

* For project planning why not this:

alias tp="T_DISPLAY=ESTTIME,WORKED,PERCENT t"
