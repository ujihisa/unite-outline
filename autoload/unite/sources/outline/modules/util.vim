"=============================================================================
" File    : autoload/unite/source/outline/modules/util.vim
" Author  : h1mesuke <himesuke@gmail.com>
" Updated : 2011-05-15
" Version : 0.3.5
" License : MIT license {{{
"
"   Permission is hereby granted, free of charge, to any person obtaining
"   a copy of this software and associated documentation files (the
"   "Software"), to deal in the Software without restriction, including
"   without limitation the rights to use, copy, modify, merge, publish,
"   distribute, sublicense, and/or sell copies of the Software, and to
"   permit persons to whom the Software is furnished to do so, subject to
"   the following conditions:
"   
"   The above copyright notice and this permission notice shall be included
"   in all copies or substantial portions of the Software.
"   
"   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"   CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

function! unite#sources#outline#modules#util#import()
  return s:Util
endfunction

"-----------------------------------------------------------------------------

function! s:get_SID()
  return matchstr(expand('<sfile>'), '<SNR>\d\+_')
endfunction
let s:SID = s:get_SID()
delfunction s:get_SID

let s:Util = unite#sources#outline#modules#base#new('Util', s:SID)

"-----------------------------------------------------------------------------
" Heading

function! s:Util_get_indent_level(context, lnum)
  let line = a:context.lines[a:lnum]
  let sw = a:context.buffer.shiftwidth
  let ts = a:context.buffer.tabstop
  let indent = substitute(matchstr(line, '^\s*'), '\t', repeat(' ', ts), 'g')
  return strlen(indent) / sw + 1
endfunction
call s:Util.function('get_indent_level')

function! s:Util_get_comment_heading_level(context, lnum, ...)
  let line = a:context.lines[a:lnum]
  if line =~ '^\s'
    let level =  (a:0 ? a:1 : s:Util_get_indent_level(a:context, a:lnum) + 3)
  else
    let level = (strlen(substitute(line, '\s*', '', 'g')) > 40 ? 2 : 3)
    let level -= (line =~ '=')
  endif
  return level
endfunction
call s:Util.function('get_comment_heading_level')

"-----------------------------------------------------------------------------
" Matching

" join_to( {context}, {lnum}, {pattern} [, {limit}])
function! s:Util_join_to(context, lnum, pattern, ...)
  let lines = a:context.lines
  let limit = (a:0 ? a:1 : 3)
  if limit < 0
    return s:join_to_backward(lines, a:lnum, a:pattern, limit * -1)
  endif
  let lnum = a:lnum
  let limit = min([a:lnum + limit, len(lines) - 1])
  while lnum <= limit
    let line = lines[lnum]
    if line =~# a:pattern
      break
    endif
    let lnum += 1
  endwhile
  return join(lines[a:lnum : lnum], "\n")
endfunction
call s:Util.function('join_to')

function! s:join_to_backward(context, lnum, pattern, limit)
  let lines = a:context.lines
  let limit = max(1, a:lnum - a:limit])
  while lnum > 0
    let line = lines[lnum]
    if line =~# a:pattern
      break
    endif
    let lnum -= 1
  endwhile
  return join(lines[lnum : a:lnum], "\n")
endfunction

function! s:Util_join_to_rparen(context, lnum, ...)
  let limit = (a:0 ? a:1 : 3)
  let line = s:Util_join_to(a:context, a:lnum, ')', limit)
  let line = substitute(line, "\\s*\n\\s*", ' ', 'g')
  let line = substitute(line, ')\zs.*$', '', '')
  return line
endfunction
call s:Util.function('join_to_rparen')

" neighbor_match( {context}, {lnum}, {pattern} [, {range} [, {exclusive}])
function! s:Util_neighbor_match(context, lnum, pattern, ...)
  let lines = a:context.lines
  let range = get(a:000, 0, 1)
  let exclusive = !!get(a:000, 1, 0)
  if type(range) == type([])
    let [prev, next] = range
  else
    let [prev, next] = [range, range]
  endif
  let [bwd_range, fwd_range] = s:neighbor_ranges(a:context, a:lnum, prev, next, exclusive)
  for lnum in bwd_range
    if lines[lnum] =~# a:pattern
      return 1
    endif
  endfor
  for lnum in fwd_range
    if lines[lnum] =~# a:pattern
      return 1
    endif
  endfor
  return 0
endfunction
call s:Util.function('neighbor_match')

function! s:neighbor_ranges(context, lnum, prev, next, exclusive)
  let max_lnum = len(a:context.lines) - 1
  let bwd_range = range(max([1, a:lnum - a:prev]), max([1, a:lnum - a:exclusive]))
  let fwd_range = range(min([a:lnum + a:exclusive, max_lnum]), min([a:lnum + a:next, max_lnum]))
  return [bwd_range, fwd_range]
endfunction

" neighbor_matchstr( {context}, {lnum}, {pattern} [, {range} [, {exclusive}])
function! s:Util_neighbor_matchstr(context, lnum, pattern, ...)
  let lines = a:context.lines
  let range = get(a:000, 0, 1)
  let exclusive = !!get(a:000, 1, 0)
  if type(range) == type([])
    let [prev, next] = range
  else
    let [prev, next] = [range, range]
  endif
  let [bwd_range, fwd_range] = s:neighbor_ranges(a:context, a:lnum, prev, next, exclusive)
  for lnum in bwd_range
    let matched = matchstr(lines[lnum], a:pattern)
    if !empty(matched)
      return matched
    endif
  endfor
  for lnum in fwd_range
    let matched = matchstr(lines[lnum], a:pattern)
    if !empty(matched)
      return matched
    endif
  endfor
  return ""
endfunction
call s:Util.function('neighbor_matchstr')

let s:SHARED_PATTERNS = {
      \ '*': {
      \   'parameter_list': '([^)]*)',
      \   'parameter_list_and_after': '([^)]*).*$',
      \   'after_lbrace'  : '{.*$',
      \   'after_lbracket': '[.*$',
      \   'after_lparen'  : '(.*$',
      \   'after_colon'   : ':.*$',
      \ },
      \ 'c': {
      \   'heading-1': '^\s*\/\*\s*[-=*]\{10,}\s*$',
      \   'header'   : ['^/\*', '\*/\s*$'],
      \ },
      \ 'cpp': {
      \   'heading-1': '^\s*/[/*]\s*[-=/*]\{10,}\s*$',
      \   'header'   : {
      \     'leading': '^//',
      \     'block'  : ['^/\*', '\*/\s*$'],
      \   },
      \ },
      \ 'sh': {
      \   'heading-1': '^\s*#\s*[-=#]\{10,}\s*$',
      \   'header'   : '^#',
      \ },
      \}

function! s:Util_shared_pattern(filetype, which)
  return s:SHARED_PATTERNS[a:filetype][a:which]
endfunction
call s:Util.function('shared_pattern')

"-----------------------------------------------------------------------------
" List

let s:List = unite#sources#outline#modules#base#new('List', s:SID)
let s:Util.List = s:List

function! s:List_sort_by_lnum(dicts)
  return sort(a:dicts, 's:compare_by_lnum')
endfunction
function! s:compare_by_lnum(d1, d2)
  let n1 = a:d1.lnum
  let n2 = a:d2.lnum
  return n1 == n2 ? 0 : n1 > n2 ? 1 : -1
endfunction
call s:List.function('sort_by_lnum')

function! s:List_split(list, sep)
  let result = []
  let sub_list = []
  for value in a:list
    if value == a:sep
      call add(result, sub_list)
      let sub_list = []
    else
      call add(sub_list, value)
    endif
  endfor
  call add(result, sub_list)
  return result
endfunction
call s:List.function('split')

function! s:List_join(lists, sep)
  let result = []
  for sub_list in a:lists
    let result += sub_list
    let result += [a:sep]
  endfor
  call remove(result, -1)
  return result
endfunction
call s:List.function('join')

function! s:List_zip(list1, list2)
  return map(range(len(a:list1)), '[a:list1[v:val], a:list2[v:val]]')
endfunction
call s:List.function('zip')

unlet s:List

"-----------------------------------------------------------------------------
" Path

let Path = unite#sources#outline#modules#base#new('Path', s:SID)
let s:Util.Path = Path

" Path.normalize( {path} [, {mods}])
function! s:Path_normalize(path, ...)
  let path = a:path
  if a:0
    let mods = a:0
    let path = fnamemodify(path, mods)
  endif
  let path = substitute(path, '[/\\]', '/', 'g')
  return path
endfunction
call Path.function('normalize')

unlet Path

"-----------------------------------------------------------------------------
" String

let String = unite#sources#outline#modules#base#new('String', s:SID)
let s:Util.String = String

" String.capitalize( {str} [, {flag}])
function! s:String_capitalize(str, ...)
  let flag = (a:0 ? a:1 : '')
  return substitute(a:str, '\<\(\h\)\(\w\+\)\>', '\u\1\L\2', flag)
endfunction
call String.function('capitalize')

" Ported from:
" Sample code from Programing Ruby, page 145
"
function! s:String_nr2roman(nr)
  if a:nr <= 0 || 4999 < a:nr
    return string(a:nr)
  endif
  let factors = [
        \ ["M", 1000], ["CM", 900], ["D",  500], ["CD", 400],
        \ ["C",  100], ["XC",  90], ["L",   50], ["XL",  40],
        \ ["X",   10], ["IX",   9], ["V",    5], ["IV",   4],
        \ ["I",    1],
        \]
  let nr = a:nr
  let roman = ""
  for [code, factor] in factors
    let cnt = nr / factor
    let nr  = nr % factor
    if cnt > 0
      let roman .= repeat(code, cnt)
    endif
  endfor
  return roman
endfunction
call String.function('nr2roman')

function! s:String_shellescape(str)
  if &shell =~? '^\%(cmd\%(\.exe\)\=\|command\.com\)\%(\s\|$\)'
    return '"' . substitute(a:str, '"', '""', 'g') . '"'
  else
    return "'" . substitute(a:str, "'", "'\\\\''", 'g') . "'"
  endif
endfunction
call String.function('shellescape')

unlet String

"-----------------------------------------------------------------------------
" Misc

function! s:Util_print_debug(msg)
  if get(g:, 'unite_source_outline_debug', 0)
    echomsg "unite-outline: " . a:msg
  endif
endfunction
call s:Util.function('print_debug')

function! s:Util_print_progress(msg)
  redraw
  echon a:msg
endfunction
call s:Util.function('print_progress')

function! s:Util__cpp_is_in_comment(heading_line, matched_line)
  return ((a:matched_line =~ '^\s*//'  && a:heading_line =~ '^\s*//') ||
        \ (a:matched_line =~ '^\s*/\*' && a:matched_line !~ '\*/\s*$'))
endfunction
call s:Util.function('_cpp_is_in_comment')

" vim: filetype=vim
