#lang scribble/manual

@(define pkgname onscreen)
@(define reponame litchar)

@title{Planet 2: Package Distribution (Beta)}
@author[@author+email["Jay McCarthy" "jay@racket-lang.org"]]

Planet 2 is a system for managing the use of external code packages in
your Racket installation.

@table-of-contents[]

@section{Planet 2 Concepts}

A @deftech{package} is a set of modules from some number of
collections. @tech{Packages} also have associated @tech{package
metadata}.

@deftech{Package metadata} is:
@itemlist[
 @item{a name -- a string made of the characters: @litchar{a-zA-Z0-9_-}.}
 @item{a list of dependencies -- a list of strings that name other packages that must be installed simultaneously.}
 @item{a checksum -- a string that identifies different releases of a package.} 
]

A @tech{package} is typically represented by a directory with the same
name as the package which contains a file named
@filepath{METADATA.rktd} formatted as:
@verbatim{
 ((dependency "dependency1" ... "dependencyn"))
}
The checksum is typically left implicit.

A @deftech{package source} identifies a @tech{package}
representation. Each package source type has a different way of
storing the checksum. The valid package source types are:

@itemlist[

@item{a local file path naming an archive -- The name of the package
is the basename of the archive file. The checksum for archive
@filepath{f.ext} is given by the file @filepath{f.ext.CHECKSUM}. For
example, @filepath{~/tic-tac-toe.zip}'s checksum would be inside
@filepath{~/tic-tac-toe.zip.CHECKSUM}. The valid archive formats
are (currently): @filepath{.zip}, @filepath{.tgz}, and
@filepath{.plt}. }

@item{a local directory -- The name of the package is the name of the
directory. The checksum is not present. For example,
@filepath{~/tic-tac-toe}.}

@item{a remote URL naming an archive -- This type follows the same
rules as a local file path, but the archive and checksum files are
accessed via HTTP(S). For example,
@filepath{http://game.com/tic-tac-toe.zip} and
@filepath{http://game.com/tic-tac-toe.zip.CHECKSUM}.}

@item{a remote URL naming a directory -- The remote directory must
contain a file named @filepath{MANIFEST} that lists all the contingent
files. These are downloaded into a local directory and then the rules
for local directory paths are followed. However, if the remote
directory contains a file named @filepath{.CHECKSUM}, then it is used
to determine the checksum. For example,
@filepath{http://game.com/tic-tac-toe/} and
@filepath{http://game.com/tic-tac-toe/.CHECKSUM}}

@item{a remote URL naming a GitHub repository -- The format for such
URLs is:
@filepath{github://github.com/<user>/<repository>/<branch>/<path>/<to>/<package>/<directory>}. The
Zip formatted archive for the repository (generated by GitHub for
every branch) is used as a remote URL archive path, except the
checksum is the hash identifying the branch. For example,
@filepath{github://github.com/game/tic-tac-toe/master/}.}

@item{a bare package name -- The local list of @tech{package name
services} is consulted to determine the source and checksum for the
package. For example, @pkgname{tic-tac-toe}.}

]

A @deftech{package name service} (PNS) is a string representing a URL,
such that appending @filepath{/pkg/<package-name>} to it will respond
with a @racket[read]-able hash table with the keys: @racket['source]
bound to the source and @racket['checksum] bound to the
checksum. Typically, the source will be a remote URL string.

PLT supports two @tech{package name services}, which are enabled by
default: @filepath{https://plt-etc.byu.edu:9004} for new Planet 2
packages and @filepath{https://plt-etc.byu.edu:9003} for
automatically generated Planet 2 packages for old Planet 1
packages. Anyone may host their own @tech{package name service}. The
source for the PLT-hosted servers is in the
@racket[(build-path (find-collects-dir) "meta" "planet2-index")]
directory.

After a package is installed, the original source of its installation
is recorded, as well as if it was an @tech{automatic installation}. An
@deftech{automatic installation} is one that was installed because it
was a dependency of a non-@tech{automatic installation} package.

Two packages are in @deftech{conflict} if they contain the same
module. For example, if the package @pkgname{tic-tac-toe} contains the
module file @filepath{data/matrix.rkt} and the package
@pkgname{factory-optimize} contains the module file
@filepath{data/matrix.rkt}, then @pkgname{tic-tac-toe} and
@pkgname{factory-optimize} are in conflict. A package may also be in
conflict with Racket itself, if it contains a module file that is part
of the core Racket distribution. For example, any package that
contains @filepath{racket/list.rkt} is in conflict with Racket. For
the purposes of conflicts, a module is a file that ends in
@litchar{.rkt} or @litchar{.ss}.

Package A is a @deftech{package update} of Package B if (1) B is
installed, (2) A and B have the same name, and (3) A's checksum is
different than B's.

@section{Using Planet 2}

Planet 2 has two user interfaces: a command line @exec{raco}
sub-command and a library. They have the exact same capabilities, as
the command line interface invokes the library functions and
reprovides all their options.

@subsection{Command Line}

The @exec{raco pkg} sub-command provides the following
sub-sub-commands:

@itemlist[

@item{@exec{install pkg ...} -- Installs the list of packages. It accepts the following options:

 @itemlist[

 @item{@DFlag{dont-setup} -- Does not run @exec{raco setup} after installation. This behavior is also the case if the environment variable @envvar{PLT_PLANET2_DONTSETUP} is set to @litchar{1}.}

 @item{@DFlag{installation} -- Install system-wide rather than user-local.}

 @item{@Flag{i} -- Alias for @DFlag{installation}.}

 @item{@DFlag{deps} @exec{dep-behavior} -- Selects the behavior for dependencies. The options are:
  @itemlist[
   @item{@exec{fail} -- Cancels the installation if dependencies are unmet (default for most packages)}
   @item{@exec{force} -- Installs the package(s) despite missing dependencies (unsafe)}
   @item{@exec{search-ask} -- Looks for the dependencies on the configured @tech{package name services} (default if the dependency is an indexed name) but asks if you would like it installed.}
   @item{@exec{search-auto} --- Like @exec{search-ask}, but does not ask for permission to install.}
  ]}

  @item{@DFlag{force} -- Ignores conflicts (unsafe.)}

  @item{@DFlag{ignore-checksums} -- Ignores errors verifying package checksums (unsafe.)}

  @item{@DFlag{link} -- When used with a directory package, leave the directory in place, but add a link to it in the package directory. This is a global setting for all installs for this command instance, which means it affects dependencies... so make sure the dependencies exist first.}
 ]
}


@item{@exec{update pkg ...} -- Checks the list of packages for
@tech{package updates}. If no packages are given, checks every
installed package. If an update is found, but it cannot be
installed (e.g. it is conflicted with another installed package), then
this command fails atomically. It accepts the following options:

 @itemlist[
 @item{@DFlag{dont-setup} -- Same as for @exec{install}.}
 @item{@DFlag{installation} -- Same as for @exec{install}.}
 @item{@Flag{i} -- Same as for @exec{install}.}
 @item{@DFlag{deps} @exec{dep-behavior} -- Same as for @exec{install}.}
 @item{@DFlag{update-deps} -- Checks the named packages, and their dependencies (transitively) for updates.}
 ]
}

@item{@exec{remove pkg ...} -- Attempts to remove the packages. If a package is the dependency of another package that is not listed, this command fails atomically. It accepts the following options:

 @itemlist[
 @item{@DFlag{dont-setup} -- Same as for @exec{install}.}
 @item{@DFlag{installation} -- Same as for @exec{install}.}
 @item{@Flag{i} -- Same as for @exec{install}.}
 @item{@DFlag{force} -- Ignore dependencies when removing packages.}
 @item{@DFlag{auto} -- Remove packages that were installed by the @exec{search-auto} and @exec{search-ask} dependency behavior that are no longer required.}
 ]
}

@item{@exec{show} -- Print information about currently installed packages. It accepts the following options:

 @itemlist[
 @item{@DFlag{installation} -- Same as for @exec{install}.}
 @item{@Flag{i} -- Same as for @exec{install}.}
 ]
}

@item{@exec{config key val ...} -- View and modify Planet 2 configuration options. It accepts the following options:

 @itemlist[
 @item{@DFlag{installation} -- Same as for @exec{install}.}
 @item{@Flag{i} -- Same as for @exec{install}.}
 @item{@DFlag{set} -- Sets an option, rather than printing it.}
 ]

 The valid keys are:
 @itemlist[
  @item{@exec{indexes} -- A list of URLs for @tech{package name services}.}           
 ]
}

@item{@exec{create package-directory} -- Bundles a package. It accepts the following options:

 @itemlist[
 @item{@DFlag{format str} -- Specifies the archive format. The options are: @exec{tgz}, @exec{zip}, and @exec{plt} (default.)}
 @item{@DFlag{manifest} -- Creates a manifest file for a directory, rather than an archive.}
 ]
}
]

@subsection{Programmatic}
@(require (for-label planet2))

@defmodule[planet2]

The @racketmodname[planet2] module provides a programmatic interface to
the command sub-sub-commands. Each long form option is keyword
argument. @DFlag{deps} accepts its argument as a symbol and
@DFlag{format} accepts its argument as a string. All other options
accept booleans, where @racket[#t] is equivalent to the presence of
the option.

@deftogether[
 (@defthing[install procedure?]             
  @defthing[update procedure?]             
  @defthing[remove procedure?]             
  @defthing[show procedure?]             
  @defthing[config procedure?]             
  @defthing[create procedure?])             
]{
 Duplicates the command line interface.  
}

@section{Developing Planet 2 Packages}

This section walks through the setup for a basic Planet 2 package.

First, make a directory for your package and select its name:

@commandline{mkdir <package-name>}

Next, link your development directory to your local package
repository:

@commandline{raco pkg install --link <package-name>}

Next, enter your directory and create a basic @tech{package metadata}
file:

@commandline{cd <package-name>}
@commandline{echo "((dependency))" > METADATA.rktd}

This metadata file is not necessary if you have no dependencies, but
you may wish to create it to simplify adding dependencies in the
future.

Next, inside this directory, create directories for the collections
and modules that your package will provide. For example,
the developer of @pkgname{tic-tac-toe} might do:

@commandline{mkdir -p games/tic-tac-toe}
@commandline{touch games/tic-tac-toe/info.rkt}
@commandline{touch games/tic-tac-toe/main.rkt}
@commandline{mkdir -p data}
@commandline{touch data/matrix.rkt}

After your package is ready to deploy choose one of the following
options:

@subsection{Github Deployment}

First, create a free account on
Github (@link["https://github.com/signup/free"]{signup here}). Then
create a repository for your
package (@link["https://github.com/new"]{here} (@link["https://help.github.com/articles/create-a-repo"]{documentation}).)
Then initialize the Git repository locally and do your first push:

@commandline{git init}
@commandline{git add *}
@commandline{git commit -m "First commit"}
@commandline{git remote add origin https://github.com/<username>/<package-name>.git}
@commandline{git push -u origin master}

Now, publish your package source as:

@exec{github://github.com/<username>/<package-name>/<branch>}

(Typically, <branch> will be @litchar{master}, but you may wish to use
different branches for releases and development.)

Now, whenever you

@commandline{git push}

Your changes will automatically be discovered by those who used your
package source.

@subsection{Manual Deployment}

Alternatively, you can deploy your package by publishing it on a URL
you control. If you do this, it is preferable to create an archive
first:

@commandline{raco pkg create <package-name>}

And then upload the archive and its checksum to your site:

@commandline{scp <package-name>.plt <package-name>.plt.CHECKSUM your-host:public_html/}

Now, publish your package source as:

@exec{http://your-host/~<username>/<package-name>.plt}

Now, whenever you want to release a new version, recreate and reupload
the package archive (and checksum). Your changes will automatically be
discovered by those who used your package source.

@subsection{Helping Others Discover Your Package}

By using either of the above deployment techniques, anyone will be
able to use your package. However, they will not be able to refer to
it by name until it is listed on a @tech{package name service}.

If you'd like to use the official @tech{package name service}, browse
to
@link["https://plt-etc.byu.edu:9004/manage/upload"]{https://plt-etc.byu.edu:9004/manage/upload}
and upload a new package. You will need to create an account and log
in first.

You only need to go to this site @emph{once} to list your package. The
server will periodically check the package source you designate for
updates.

If you use this server, and use Github for deployment, then you will
never need to open a Web browser to update your package for end
users. You just need to push to your Github repository, then within 24
hours, the official @tech{package name service} will notice, and
@exec{raco pkg update} will work on your user's machines.

@subsection{Naming and Designing Packages}

Although of course not required, we suggest the following system for
naming and designing packages:

@itemlist[

@item{Packages should not include the name of the author or
organization that produces them, but be named based on the content of
the package. For example, @pkgname{data-priority-queue} is preferred
to @pkgname{johns-amazing-queues}.}

@item{Packages that provide an interface to a foreign library or
service should be named the same as the service. For example,
@pkgname{cairo} is preferred to @pkgname{Racket-cairo} or a similar
name.}

@item{Packages should not generally contain version-like elements in
their names, initially. Instead, version-like elements should be added
when backwards incompatible changes are necessary. For example,
@pkgname{data-priority-queue} is preferred to
@pkgname{data-priority-queue1}. Exceptions include packages that
present interfaces to external, versioned things, such as
@pkgname{sqlite3} or @pkgname{libgtk2}.}

@item{Packages should not include large sets of utilities libraries
that are likely to cause conflicts. For example, packages should not
contain many extensions to the @filepath{racket} collection, like
@filepath{racket/more-lists.rkt} and
@filepath{racket/more-bools.rkt}. Instead, such as extensions should
be separated into their own packages.}

@item{Packages should generally provide one collection with a name
similar to the name of the package. For example, @pkgname{libgtk1}
should provide a collection named @filepath{libgtk}. Exceptions
include extensions to existing collection, such as new data-structures
for the @filepath{data} collection, DrRacket tools, new games for PLT
Games, etc.}

@item{Packages are not allowed to start with @pkgname{plt},
@pkgname{racket}, or @pkgname{planet} without special approval from
PLT curation.}

]

@section{Planet 1 Compatibility}

PLT maintains a Planet 1 compatibility @tech{package name service} at
@link["https://plt-etc.byu.edu:9003/"]{https://plt-etc.byu.edu:9003/}. This
PNS is included by default in the Planet search path.

Planet 2 copies of Planet 1 packages are automatically created by this
server according to the following system: for all packages that are in
the @litchar{4.x} Planet 1 repository, the latest minor version of
@tt{<user>/<package>.plt/<major-version>} will be available as
@pkgname{planet-<user>-<package><major-version>}. For example,
@tt{jaymccarthy/opencl.plt/1} minor version @tt{2}, will be available as
@pkgname{planet-jaymccarthy-opencl1}.

The contents of these copies is a single collection with the name
@filepath{<user>/<package><major-version>} with all the files from the
original Planet 1 package in it.

Each file has been transliterated to use direct Racket-style requires
rather than Planet 1-style requires. For example, if any file contains
@racket[(planet jaymccarthy/opencl/module)], then it is transliterated
to @racket[jaymccarthy/opencl1/module]. @emph{This transliteration is
purely syntactic and is trivial to confuse, but works for most
packages, in practice.}

Any transliterations that occurred are automatically added as
dependencies for the Planet 2 compatibility package.

We do not intend to improve this compatibility system much more over
time, because it is simply a stop-gap as developers port their
packages to Planet 2. Additionally, the existence of this is not meant
to imply that we will be removing Planet 1 from existence in the near
future.

@section{FAQ}

This section answers anticipated frequently asked questions about
Planet 2.

@subsection{Are package installations versioned with respect to the
Racket version?}

No. When you install a Planet 2 package, it is installed for all
versions of Racket until you remove it. (In contrast, Planet 1
requires reinstallation of all packages every version change.)

@subsection{Where and how are packages installed?}

User-local packages are in @racket[(build-path (find-system-path
'addon-dir) "pkgs")] and installation-wide packages are in
@racket[(build-path (find-lib-dir) "pkgs")]. They are linked as
collection roots with @exec{raco link}.

@subsection{How are user-local and installation-wide packages
related?}

They are totally distinct: packages are not compared with one another
for conflicts.

This is because it would be in-feasible to check them reliably. For
example, if a system package is being installed by user A, then how
could the system know that user B exists so B's packages could be
checked for conflicts?

We anticipate that most users will only one kind of package. The
majority of users will employ user-local packages but classes or other
shared workspaces might exclusively employ installation-wide packages.

@subsection{If packages have no version numbers, how can I update
packages with error fixes, etc?}

If you have a new version of the code for a package, then it will have
a new checksum. When package updates are searched for, the checksum of
the installed package is compared with the checksum of the source, if
they are different, then the source is re-installed. This allows code
changes to be distributed.

@subsection{If packages have no version numbers, how can I specify
which version of a package I depend on if its interface has changed
and I need an old version?}

In such a situation, the author of the package has released a
backwards incompatible edition of a package. It is not possible in
Planet 2 to deal with this situation. (Other than, of course, not
installing the "update".) Therefore, package authors should not make
backwards incompatible changes to packages. Instead, they should
release a new package with a new name. For example, package
@pkgname{libgtk} might become @pkgname{libgtk2}. These packages
should be designed to not conflict with each other, as well.

@subsection{Why is Planet 2 so different than Planet 1?}

There are two fundamental differences between Planet 1 and Planet 2.

The first is that Planet 1 uses "internal linking" whereas Planet 2
uses "external linking". For example, an individual module requires a
Planet 1 package directly in a require statement:

@racketblock[
 (require (planet game/tic-tac-toe/data/matrix))
]

whereas in Planet 2, the module would simply require the module of
interest:

@racketblock[
 (require data/matrix)             
]

and would rely on the external system having the
@pkgname{tic-tac-toe} package installed.

This change is good because it makes the origin of modules more
flexible---so that code can migrate in and out of the core, packages
can easily be split up, combined, or taken over by other authors, etc.

This change is bad because it makes the meaning of your program
dependent on the state of the system. (This is already true of Racket
code in general, because there's no way to make the required core
version explicit, but the problem will be exacerbated by Planet 2.)

The second major difference is that Planet 1 is committed to
guaranteeing that packages that never conflict with one another, so
that any number of major and minor versions of the same package can be
installed and used simultaneously. Planet 2 does not share this
commitment, so package authors and users must be mindful of potential
conflicts and plan around them.

This change is good because it is simpler and lowers the burden of
maintenance (provided most packages don't conflict.)

The change is bad because users must plan around potential conflicts.

In general, the goal of Planet 2 is to be a lower-level package
system, more like the package systems used by operating systems. The
goals of Planet 1 are not bad, but we believe they are needed
infrequently and a system like Planet 1 could be more easily built
atop Planet 2 than the reverse.

In particular, our plans to mitigate the downsides of these changes
are documented in @secref["short-term"].

@section{Future Plans}

@subsection[#:tag "short-term"]{Short Term}

This section lists some short term plans for Planet 2. These are
important, but didn't block its release. Planet 2 will be considered
out of beta when these are completed.

@itemlist[

@item{It has not been tested on Windows or Mac OS X. If you would like
to test it, please run @exec{racket
collects/tests/planet2/test.rkt}. It is recommended that you run this
with the environment variable @envvar{PLT_PLANET2_DONTSETUP} set to
@litchar{1}. (The tests that require @exec{raco setup} to run
explicitly ignore the environment of the test script.)}

@item{The official PNS will divide packages into three
categories: @reponame{planet}, @reponame{solar-system}, and @reponame{galaxy}. The definitions
for these categories are:

 @itemlist[

  @item{@reponame{galaxy} -- No restrictions.}

  @item{@reponame{solar-system} -- Must not conflict any package
in @reponame{solar-system} or @reponame{planet}.}

  @item{@reponame{planet} -- Must not conflict any package in @reponame{solar-system}
or @reponame{planet}. Must have documentation and tests. The author must be
responsive about fixing regressions against changes in Racket, etc.}

 ]

This categories will be curated by PLT.

Our goal is for all packages to be in the @reponame{solar-system}, with
the @reponame{galaxy} as a temporary place while the curators work with the
authors of conflicting packages to determine how modules should be
renamed for unity.

However, before curation is complete, each package will be
automatically placed in @reponame{galaxy} or @reponame{solar-system}
depending on its conflicts, with preference being given to older
packages. (For example, if a new package B conflicts with an old
package A, then A will be in @reponame{solar-system}, but B will be in
@reponame{galaxy}.) During curation, however, it is not necessarily
the case that older packages have preference. (For example,
@pkgname{tic-tac-toe} should probably not provide
@filepath{data/matrix.rkt}, but that could be spun off into another
package used by both @pkgname{tic-tac-toe} and
@pkgname{factory-optimize}.)

In contrast, the @reponame{planet} category will be a special category that
authors may apply for. Admission requires a code audit and implies
a "stamp of approval" from PLT. In the future, packages in this
category will have more benefits, such as automatic regression testing
on DrDr, testing during releases, provided binaries, and advertisement
during installation.

The Planet 1 compatibility packages will also be included in
the @reponame{solar-system} category, automatically. 

}

@item{In order to mitigate the costs of external linking vis a vis the
inability to understand code in isolation, we will create a module
resolver that searches for providers of modules on the configured
@tech{package name services}. For example, if a module requires
@filepath{data/matrix.rkt}, and it is not available, then the PNS will
be consulted to discover what packages provide it. @emph{Only packages
in @reponame{solar-system} or @reponame{planet} will be
returned.} (This category restriction ensures that the package to
install is unique.)

Users can configure their systems to then automatically install the
package provided is has the appropriate category (i.e., some users may
wish to automatically install @reponame{planet} packages but not
@reponame{solar-system} packages, while others may not want to install
any.)

This feature will be generalized across all @tech{package name
services}, so users could maintain their own category definitions with
different policies.}

]

@subsection{Long Term}

This section lists some long term plans for Planet 2. Many of these
require a lot of cross-Racket integration.

@itemlist[

@item{The official PNS is bare bones. It could conceivably do a lot
more: keep track of more statistics, enable "social" interactions
about packages, link to documentation, problem reports, licenses,
etc. Some of this is easy and obvious, but the community's needs are
unclear.}

@item{It would be nice to encrypt information from the official
@tech{package name service} with a public key shipped with Racket, and
allow other services to implement a similar security scheme.}

@item{Packages in the @reponame{planet} category should be tested on
DrDr. This would require a way to communicate information about how
they should be run to DrDr. This is currently done via the
@filepath{meta/props} script for things in the core. We should
generalize this script to a @filepath{meta/props.d} directory so that
packages can install DrDr metadata to it.}

@item{We hope that this package system will encourage more incremental
improvements to pieces of Racket. In particular, it would be wonderful
to have a very thorough @filepath{data} collection of different
data-structures. However, our existing setup for Scribble would force
each new data structue to have a different top-level documentation
manual, rather than extending the documentation of the existing
@filepath{data} collection. Similar issues will exist for the
@filepath{net} and @filepath{file} collections. We should design a way
to have such "documentation plugins" in Scribble and support
similar "plugin" systems elsewhere in the code-base.}

@item{Packages can contain any kinds of files, including bytecode and
documentation, which would reduce the time required to install a
package (since we must run @exec{raco setup}). However, packages with
these included are painful to maintain and unreliable given users with
different versions of Racket installed.

One solution is to have a separate place where such "binary" packages
are available. For example, PLT could run a PNS for every Racket
version, i.e., @filepath{https://binaries.racket-lang.org/5.3.1.4},
that would contain the binaries for all the packages in the
@reponame{planet} category. Thus, when you install package
@pkgname{tic-tac-toe} you could also install the binary version from
the appropriate PNS.

There are obvious problems with this... it could be expensive for PLT
in terms of space and time... Racket compilation is not necessarily
deterministic or platform-independent.

This problem requires more thought.}

@item{The user interface could be improved, including integration with
DrRacket and a GUI. For example, it would be good if DrRacket would
poll for package updates periodically and if when it was first started
it would display available, popular packages.}

@item{The core distribution should be split apart into many more
packages. For example, Redex, Plot, the Web Server, and the teaching
languages are natural candidates for being broken off.}

@item{The core should be able to be distributed with packages that
will be installed as soon as the system is installed. Ideally, this
would be customizable by instructors so they could share small
distributions with just the right packages for their class.}

]