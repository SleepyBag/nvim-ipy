"command! -nargs=* IPythonKernel :call IPyConnect( "--no-window", <f-args>)
"command! -nargs=* IPython2Kernel :call IPyConnect("--kernel", "python2", "--no-window")
"command! -nargs=* IJulia :call IPyConnect("--kernel", "julia-0.4")
"command! IPySplitTerm :call <SID>split_term()
command! Ipy :call ToggleIPython()
command! Ipy2 :call ToggleIPython2()

nnoremap <Plug>(IPy-Word) <Cmd>call IPyRun(expand("<cword>"))<cr>
nnoremap <Plug>(IPy-Run) <Cmd>call IPyRun(getline('.')."\n")<cr>
vnoremap <Plug>(IPy-Run) :<c-u>call IPyRun(<SID>get_visual_selection())<cr>
nnoremap <Plug>(IPy-RunCell) <Cmd>call IPyRunCell()<cr>
nnoremap <Plug>(IPy-RunAll) :call IPyRun(join(getline(1, '$'), "\n"))<cr>
inoremap <Plug>(IPy-Complete) <Cmd>call IPyComplete()<cr>
noremap <Plug>(IPy-WordObjInfo) :call IPyObjInfo(<SID>get_current_word(), 0)<cr>
noremap <Plug>(IPy-Interrupt) <Cmd>call IPyInterrupt()<cr>
noremap <Plug>(IPy-Terminate) <Cmd>call IPyTerminate()<cr>

" make this overrideable
hi IPyIn ctermfg=green cterm=bold guifg=LimeGreen gui=bold
hi IPyOut ctermfg=red cterm=bold guifg=red gui=bold
hi IPyBold cterm=bold gui=bold
let s:colors = ["Black", "Red", "Green", "DarkYellow", "Blue", "DarkMagenta", "#00bbdd", "LightGray",
             \  "Gray", "#ff4444", "LimeGreen", "Yellow", "LightBlue", "Magenta", "Cyan", "White"]
let s:ipython_kernel_opened = 0
let s:ipython2_kernel_opened = 0
let s:currentWindow = -1
let g:ipython_window_height = 10
let s:termjob = -1
for i in range(0,15)
    execute "hi IPyFg".i." ctermfg=".i." guifg=".s:colors[i]
endfor

function! ToggleIPython()
    if s:currentWindow == -1
        call OpenIPython()
    else
        exec(s:currentWindow.'wincmd w')
        exec('wincmd q')
        let s:currentWindow = -1
    endif
endfunction

function! ToggleIPython2()
    if s:currentWindow == -1
        call OpenIPython2()
    else
        exec(s:currentWindow.'wincmd w')
        exec('wincmd q')
        let s:currentWindow = -1
    endif
endfunction

function! IPyInterrupt()
    call chansend(s:termjob, "\003")
endfunction

function! IPyTerminate()
    call IPyTerminateImpl()
    let s:ipython_kernel_opened = 0
    let s:ipython2_kernel_opened = 0
endfunction

function! OpenIPython()
    if s:ipython_kernel_opened == 0
        call IPyConnect("--no-window")
        let s:ipython_kernel_opened = 1
    endif
    call s:split_term()
    exec('resize '.g:ipython_window_height)
    let s:currentWindow = winnr()
    exec('wincmd p')
endfunction

function! OpenIPython2()
    if s:ipython2_kernel_opened == 0
        call IPyConnect("--kernel", "python2", "--no-window")
        let s:ipython2_kernel_opened = 1
    endif
    call s:split_term()
    exec('resize '.g:ipython_window_height)
    let s:currentWindow = winnr()
    exec('wincmd p')
endfunction

function! s:split_term()
    let cfile = IPyConnFile()
    new
    let s:termjob = termopen(['jupyter', 'console', '--existing', cfile])
    "startinsert
endfunction

function! s:get_current_word()
    let isk_save = &isk
    let &isk = '@,48-57,_,192-255,.'
    let word = expand("<cword>")
    let &isk = isk_save
    return word
endfunction

" thanks to @xolox on stackoverflow
function! s:get_visual_selection()
    let [lnum1, col1] = getpos("'<")[1:2]
    let [lnum2, col2] = getpos("'>")[1:2]

    if lnum1 > lnum2
      let [lnum1, col1, lnum2, col2] = [lnum2, col2, lnum1, col1]
    endif

    let lines = getline(lnum1, lnum2)
    let lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][col1 - 1:]
    return join(lines, "\n")."\n"
endfunction

function! s:get_scoped(key,default)
    if has_key(b:, a:key)
        return b:[a:key]
    else
        return get(g:,a:key,a:default)
    end
endfunction

function! s:saveCur()
    " from matchit
    let restore_cursor = virtcol(".") . "|"
    normal! g0
    let restore_cursor = line(".") . "G" .  virtcol(".") . "|zs" . restore_cursor
    normal! H
    let restore_cursor = "normal!" . line(".") . "Gzt" . restore_cursor
    execute restore_cursor
    return restore_cursor
endfunction

function! s:select(mode, start, end)
    execute "normal! ".a:mode
    call cursor(a:start[0], a:start[1])
    normal! o
    call cursor(a:end[0], a:end[1])
    if &selection ==# 'exclusive'
        normal! l
    endif
endfunction

"function! Trim(str)
"    let str = a:str
"    let prestr = substitute(str, "\ *$", "", "")
"    let trimed_str = substitute(prestr, "^\ *", "", "")
"    let space = substitute(prestr, '\V'.trimed_str, "", "")
"    return [str, space]
"endfunction

function! IPyRun(str)
    if s:currentWindow == -1
        call OpenIPython()
    endif
    let strs = split(a:str, "\n")
    for str in strs
        call chansend(s:termjob, "\0330C")
        call chansend(s:termjob, str."\033o")
        "exec 'sleep 100m'
    endfor
    call chansend(s:termjob, "\n\n")
    exec s:currentWindow."wincmd w"
    exec 'normal G'
    exec s:currentWindow."wincmd p"
endfunction

" TODO: make me a reusable text object
function! IPyRunCell()
    let def = s:get_scoped("ipy_celldef", "^##")
    if type(def) == v:t_list
        let implicit = v:false
        let [start, end] = def
    else
        let implicit = v:true
        let start = def
        let end = def
    endif
    let curline = line('.')
    let lnum2 = search(end, 'nW')
    if lnum2 == 0
        if implicit
            let lnum2 = line('$')+1
        else
            return 0
        end
    endif
    let reset =  s:saveCur()
    call cursor(lnum2,1)
    let lnum1 = search(start, 'bnW')
    execute reset
    if lnum1 == 0 && !implicit
        return 0
    endif
    let lines = getline(lnum1+1, lnum2-1)
    echomsg "".lnum1.":".lnum2
    while len(lines) > 0 && match(lines[0], '^\s*$') > -1
        let lines = lines[1:]
    endwhile
    call IPyRun(join(lines, "\n"))
    return 1
endfunction


if !exists('g:nvim_ipy_perform_mappings')
    let g:nvim_ipy_perform_mappings = 1
endif

let g:ipy_status = ""

if g:nvim_ipy_perform_mappings
    map <silent> <F5>           <Plug>(IPy-Run)
    imap <silent> <C-F> <Plug>(IPy-Complete)
    map <silent> <F8> <Plug>(IPy-Interrupt)
    map <silent> <leader>? <Plug>(IPy-WordObjInfo)
    "set titlestring=%t%(\ %M%)%(\ (%{expand(\"%:p:h\")})%)%(\ %a%)%(\ -\ %{g:ipy_status}%)
endif


