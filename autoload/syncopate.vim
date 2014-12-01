" Copyright 2014 Google Inc. All rights reserved.
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"     http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.

let s:plugin = maktaba#plugin#Get('syncopate')


" Change vim settings to prepare for HTML export, and save the old values for
" s:SyncopateRestoreSettings().
"
" NOTE: Do not change this function without making a corresponding change in
" s:SyncopateRestoreSettings().
function! s:SyncopateSaveAndChangeSettings()
  let l:change_colorscheme = maktaba#ensure#IsBool(
      \ s:plugin.Flag('change_colorscheme'))

  " Save any settings we'll need to restore later.
  let l:setting_names = ['g:html_use_css']
  if l:change_colorscheme
    call extend(l:setting_names, ['&background', 'g:colors_name'])
  endif
  let l:settings = maktaba#value#SaveAll(l:setting_names)

  " Syncopate forces g:html_use_css to 0 (false).  This outputs ugly deprecated
  " <font> tags, but it's necessary to make sure the HTML shows up correctly in
  " email clients (which usually strip out <style> sections).
  let g:html_use_css = 0

  " Choose a more readable colorscheme for the HTML output, if desired.
  if l:change_colorscheme
    execute 'colorscheme' maktaba#ensure#IsString(s:plugin.Flag('colorscheme'))
  endif

  return l:settings
endfunction


" Restore any {settings} we changed to export the HTML.
"
" NOTE: Do not change this function without making a corresponding change in
" s:SyncopateSaveAndChangeSettings().
function! s:SyncopateRestoreSettings(settings)
  " We must restore the settings *before* changing the colorscheme, so that
  " g:colors_name will have its original value.
  call maktaba#value#Restore(a:settings)
  if maktaba#ensure#IsBool(s:plugin.Flag('change_colorscheme'))
    execute 'colorscheme' get(g:, 'colors_name', 'default')

    " We restore them again, because :colorscheme can change some of the
    " settings and we want to leave everything as we found it.  It may be
    " unlikely that anybody relies on g:colors_name being unset; however, the
    " performance hit should be truly negligible.
    call maktaba#value#Restore(a:settings)
  endif
endfunction


" Tell the user which lines were copied.
function! s:InformUserAboutCopiedText(first, last)
  redraw
  let l:message_opener = 'Syncopate exported'
  if a:first == 1 && a:last == line('$')
    echomsg l:message_opener 'the entire file.'
  else
    let l:num_lines = a:last - a:first + 1
    echomsg l:message_opener l:num_lines 'lines:' a:first 'to' a:last
  endif
endfunction


""
" Export syntax-highlighted content to a new browser tab.
"
" @throws WrongType.
function! syncopate#ExportToBrowser() range
  " Change any necessary settings to prepare for the HTML export.
  let l:settings = s:SyncopateSaveAndChangeSettings()

  " Generate the HTML.
  execute a:firstline . ',' . a:lastline 'TOhtml'

  " Try to save the HTML to a file and open it in the browser.
  let l:html_file = tempname()
  try
    execute 'saveas!' l:html_file
    let l:browser = maktaba#ensure#IsString(s:plugin.Flag('browser'))
    call system(printf("%s '%s'", l:browser, l:html_file))
  catch /E212/
    call maktaba#error#Warn('Could not write to "%s"', l:html_file)
    let l:could_not_write = 1
  endtry

  " Kill the HTML buffer (and file, if necessary).
  bwipeout!
  if get(l:, 'could_not_write', 0) == 0
    call system(printf("rm '%s'", l:html_file))
  endif

  " Restore any settings necessary.
  call s:SyncopateRestoreSettings(l:settings)
endfunction


""
" Export syntax-highlighted content directly to the clipboard.
"
" @throws WrongType.
function! syncopate#ExportToClipboard() range
  " Change any necessary settings to prepare for the HTML export.
  let l:settings = s:SyncopateSaveAndChangeSettings()

  " Generate the HTML; send it to the clipboard; kill the HTML buffer.
  execute a:firstline . ',' . a:lastline 'TOhtml'
  silent %!xclip -t text/html -selection clipboard
  bwipeout!

  " Restore any settings necessary.
  call s:SyncopateRestoreSettings(l:settings)

  " Tell the user what we did.
  call s:InformUserAboutCopiedText(a:firstline, a:lastline)
endfunction
