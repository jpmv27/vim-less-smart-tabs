" Some parts adapted from https://github.com/vim-scripts/Smart-Tabs
" With inspiration from https://www.emacswiki.org/emacs/SmartTabs

function! s:InIndent() abort
    return strpart(getline('.'), 0, col('.') - 1) =~# '^\s*$'
endfunction

function! s:SID() abort
    return matchstr(expand('<sfile>'), '\zs<SNR>\d\+_\zeSID$')
endfunction

function! s:TabWidth() abort
    if &sts > 0
        return &sts
    endif

    if exists('b:lst_saved_sw')
        if b:lst_saved_sw != 0
            return b:lst_saved_sw
        else
            return b:lst_saved_ts
        endif
    else
        if &sw != 0
            return &sw
        else
            return &ts
        endif
    endif
endfun

function! s:SetWorkingTabs() abort
    setlocal ts=256
    setlocal sw=256
endfunction

function! s:RestoreUserTabs() abort
    execute 'setlocal ts=' . b:lst_saved_ts
    execute 'setlocal sw=' . b:lst_saved_sw
endfunction

function! s:SaveContext() abort
    let b:lst_saved_ts = &ts
    let b:lst_saved_sw = &sw
    let b:lst_saved_cino = &cino
    let b:lst_saved_view = winsaveview()
endfunction

function! s:RestoreContext() abort
    call s:RestoreUserTabs()
    execute 'setlocal cino=' . b:lst_saved_cino

    let cursor = getcurpos()
    let b:lst_saved_view['lnum']     = cursor[1]
    let b:lst_saved_view['col']      = cursor[2] - 1
    let b:lst_saved_view['coladd']   = cursor[3]
    let b:lst_saved_view['curswant'] = virtcol('.') - 1
    call winrestview(b:lst_saved_view)

    unlet b:lst_saved_ts
    unlet b:lst_saved_sw
    unlet b:lst_saved_cino
    unlet b:lst_saved_view
endfunction

function! s:ConfigureSmartly() abort
    if &cin
        " Some cinoptions default to the value of shiftwidth
        " Since we are changing shiftwidth, we need to pin those
        " values to the current shiftwidth before changing it
        if &cino !~# '(\d\+'
            execute 'setlocal cino+=(' . &sw * 2
        endif
        if &cino !~# 'u\d\+'
            execute 'setlocal cino+=u' . &sw
        endif
    endif

    call s:SetWorkingTabs()
endfunction

function! s:GetPos(pos) abort
    let l = line(a:pos)
    " Work-around for virtcol() returning end of tab
    " rather than beginning. Beginning is one character
    " right of the end of the previous character
    let c = virtcol([l, col(a:pos) - 1]) + 1
    return [l, c]
endfunction

function! s:GetUserPos(pos) abort
    call s:RestoreUserTabs()
    let p = s:GetPos(a:pos)
    call s:SetWorkingTabs()
    return p
endfunction

function! s:SetCursor(pos) abort
    execute 'normal! ' . a:pos[0] . 'G' . a:pos[1] . '|'
endfunction

function! s:SetUserCursor(pos) abort
    call s:RestoreUserTabs()
    call s:SetCursor(a:pos)
    call s:SetWorkingTabs()
endfunction

function! s:CallHookBefore() abort
    return "\<c-r>=" . s:SID() . "HookBefore()\<cr>"
endfunction

function! s:CallHookAfter() abort
    return "\<c-r>=" . s:SID() . "HookAfter()\<cr>"
endfunction

function! s:MapOperator(op) abort
    execute 'noremap <buffer> <silent> ' . a:op . ' :<c-u>let b:lst_ct=v:count1<cr>:let b:lst_op="' . a:op . '"<cr>:set operatorfunc=<SID>ApplyOperator<cr>g@'
    execute 'noremap <buffer> <silent> ' . a:op . a:op . ' :<c-u>let b:lst_ct=v:count1<cr>:let b:lst_op="' . a:op . a:op . '"<cr>:call <SID>ApplyDoubleOperator()<cr>'
    execute 'vnoremap <buffer> <silent> ' . a:op . ' :<c-u>let b:lst_ct=v:count1<cr>:let b:lst_op="' . a:op . '"<cr>:call <SID>ApplyOperator(visualmode())<cr>'
    "execute 'cnoremap <buffer> <silent> ' . a:op . ' :LSTRangeOver "' . a:op . '",'
endfunction

function! s:ShiftLinesRight(l1, l2, ntabs) abort
    execute 'normal! :' . a:l1 . ',' . a:l2 . repeat('>', a:ntabs) . "\<cr>"
endfunction

function! s:ShiftLinesLeft(l1, l2, ntabs) abort
    execute 'normal! :' . a:l1 . ',' . a:l2 . repeat('<', a:ntabs) . "\<cr>"
endfunction

function! s:FilterLines(l1, l2) abort
    let nlines = abs(a:l2 - a:l1) + 1
    call s:SetUserCursor([min([a:l1, a:l2]), 1])
    execute 'normal! ' . nlines . '=='
endfunction

function! s:ShiftBlockRight(l1, l2, c, ntabs) abort
    for l in range(a:l1, a:l2)
        call s:SetUserCursor([l, a:c])

        if s:InIndent()
            execute "normal! \<c-v>" . a:ntabs . '>'
        else
            execute 'normal! i' . repeat(' ', s:TabWidth() * a:ntabs) . "\<esc>"
        endif
    endfor
endfunction

function! s:ShiftBlockLeft(l1, l2, c, ntabs) abort
    for l in range(a:l1, a:l2)
        call s:SetUserCursor([l, a:c])

        if s:InIndent()
            execute "normal! \<c-v>" . a:ntabs . '<'
        else
            execute 'normal! :s/\%' . getcurpos()[2] . 'c[ ]\{,' . (s:TabWidth() * a:ntabs) . "}//\<cr>"
        endif
    endfor
endfunction

"function! s:ApplyOperatorToRange(l1, l2, op, ...) abort
"    if a:0 == 0
"        let ct = 1
"    else
"        let ct = a:1
"    endif
"
"    call <SID>HookBefore()
"
"    echom 'a:l1='.a:l1.' a:l2='.a:l2.' ct='.ct
"    execute 'normal! :' . a:l1 . ',' . a:l2 . a:op . ct . "\<cr>"
"
"    call <SID>HookAfter()
"endfunction

function! <SID>HookBefore() abort
    call s:SaveContext()
    call s:ConfigureSmartly()

    return ''
endfunction

function! <SID>HookAfter() abort
    call s:RestoreContext()

    return ''
endfunction

function! <SID>ApplyOperator(type) abort
    if a:type ==# 'v' || a:type ==# 'V' || a:type ==# ''
        let p1 = s:GetPos("`<")
        let p2 = s:GetPos("`>")

        let l1 = p1[0]
        let l2 = p2[0]
        let nt = b:lst_ct
    elseif a:type ==# 'char' || a:type ==# 'line'
        let p1 = s:GetPos("`[")
        let p2 = s:GetPos("`]")

        let l1 = p1[0]
        " Assumes the direction of motion is down
        " There doesn't seem to be any way to tell what direction
        " was selected; this doesn't work properly when moving up
        let l2 = l1 + ((p2[0] - l1) * b:lst_ct)
        let nt = 1
    endif

    if a:type ==# ''
        let c = min([p1[1], p2[1]])
    else
        let c = 0
    endif

    call <SID>HookBefore()

    if a:type ==# ''
        if b:lst_op ==# '>'
            call s:ShiftBlockRight(l1, l2, c, nt)
        elseif b:lst_op ==# '<'
            call s:ShiftBlockLeft(l1, l2, c, nt)
        elseif b:lst_op ==# '='
            call s:FilterLines(l1, l2)
        endif
    else
        if b:lst_op ==# '>'
            call s:ShiftLinesRight(l1, l2, nt)
        elseif b:lst_op ==# '<'
            call s:ShiftLinesLeft(l1, l2, nt)
        elseif b:lst_op ==# '='
            call s:FilterLines(l1, l2)
        endif
    endif

    call <SID>HookAfter()

    if a:type !=# ''
        let c = s:GetPos('.')[1]
    endif

    call s:SetCursor([min([l1, l2]), c])

    unlet! b:lst_op
    unlet! b:lst_ct
endfunction

function! <SID>ApplyDoubleOperator() abort
    let p = s:GetPos('.')

    let l1 = p[0]
    let l2 = l1 + b:lst_ct - 1

    call <SID>HookBefore()

    if b:lst_op ==# '>>'
        call s:ShiftLinesRight(l1, l2, 1)
    elseif b:lst_op ==# '<<'
        call s:ShiftLinesLeft(l1, l2, 1)
    elseif b:lst_op ==# '=='
        call s:FilterLines(l1, l2)
    endif

    call <SID>HookAfter()

    let c = s:GetPos('.')[1]
    call s:SetCursor([l1, c])

    unlet! b:lst_op
    unlet! b:lst_ct
endfunction

function! <SID>InsertCR() abort
    return s:CallHookBefore() . "\<cr>" . s:CallHookAfter()
endfunction

function! <SID>InsertTab() abort
    if s:InIndent()
        return "\<tab>"
    endif

    let sts = s:TabWidth()
    let sp = (virtcol('.') % sts)

    if sp == 0
        let sp = sts
    endif

    return repeat(' ', 1 + sts - sp)
endfun

function! less_smart_tabs#enable() abort
    if &expandtab
        echo 'expandtab is enabled, skipped enabling less_smart_tabs'
        return
    endif

    inoremap <buffer> <silent> <expr> <tab> <SID>InsertTab()

    inoremap <buffer> <silent> <expr> <cr> <SID>InsertCR()

    call s:MapOperator('>')
    call s:MapOperator('<')
    call s:MapOperator('=')

    "command! -buffer -range -nargs=+ LSTRangeOver call s:ApplyOperatorToRange(<line1>,<line2>,<args>)
endfunction

