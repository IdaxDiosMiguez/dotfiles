
CURRENT_BG='NONE'

case ${SOLARIZED_THEME:-dark} in
    light)
      CURRENT_FG=${CURRENT_FG:-'white'}
      CURRENT_DEFAULT_FG=${CURRENT_DEFAULT_FG:-'white'}
      ;;
    *)
      CURRENT_FG=${CURRENT_FG:-'#7d956d'}
      CURRENT_DEFAULT_FG=${CURRENT_DEFAULT_FG:-'default'}
      ;;
esac

### Theme Configuration Initialization
# Main color #f38ba8
# Override these settings in your ~/.zshrc

# Current working directory
: ${AGNOSTER_DIR_FG:=${CURRENT_FG}}
: ${AGNOSTER_DIR_BG:=${CURRENT_DEFAULT_FG}}

# user@host
: ${AGNOSTER_CONTEXT_FG:=${CURRENT_FG}}
: ${AGNOSTER_CONTEXT_BG:=${CURRENT_DEFAULT_FG}}

# Git related
: ${AGNOSTER_GIT_CLEAN_FG:=${CURRENT_FG}}
: ${AGNOSTER_GIT_CLEAN_BG:=green}
: ${AGNOSTER_GIT_DIRTY_FG:=black}
: ${AGNOSTER_GIT_DIRTY_BG:=yellow}

# Bazaar related
: ${AGNOSTER_BZR_CLEAN_FG:=${CURRENT_FG}}
: ${AGNOSTER_BZR_CLEAN_BG:=green}
: ${AGNOSTER_BZR_DIRTY_FG:=black}
: ${AGNOSTER_BZR_DIRTY_BG:=yellow}

# Mercurial related
: ${AGNOSTER_HG_NEWFILE_FG:=white}
: ${AGNOSTER_HG_NEWFILE_BG:=red}
: ${AGNOSTER_HG_CHANGED_FG:=black}
: ${AGNOSTER_HG_CHANGED_BG:=yellow}
: ${AGNOSTER_HG_CLEAN_FG:=${CURRENT_FG}}
: ${AGNOSTER_HG_CLEAN_BG:=green}

# VirtualEnv colors
: ${AGNOSTER_VENV_FG:=black}
: ${AGNOSTER_VENV_BG:=blue}

# AWS Profile colors
: ${AGNOSTER_AWS_PROD_FG:=yellow}
: ${AGNOSTER_AWS_PROD_BG:=red}
: ${AGNOSTER_AWS_FG:=black}
: ${AGNOSTER_AWS_BG:=green}

# Status symbols
: ${AGNOSTER_STATUS_RETVAL_FG:=red}
: ${AGNOSTER_STATUS_ROOT_FG:=yellow}
: ${AGNOSTER_STATUS_JOB_FG:=cyan}
: ${AGNOSTER_STATUS_FG:=${CURRENT_DEFAULT_FG}}
: ${AGNOSTER_STATUS_BG:=black}

## Non-Color settings - set to 'true' to enable
# Show the actual numeric return value rather than a cross symbol.
: ${AGNOSTER_STATUS_RETVAL_NUMERIC:=false}
# Show git working dir in the style "/git/root   master  relative/dir" instead of "/git/root/relative/dir   master"
: ${AGNOSTER_GIT_INLINE:=true}
# Show the git branch status in the prompt rather than the generic branch symbol
: ${AGNOSTER_GIT_BRANCH_STATUS:=true}


# Special Powerline characters

() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  SEGMENT_SEPARATOR=$'\ue0b0'
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
SEGMENT_COUNT=0

prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"

  # Professional Logic: Only add 'in' after the Context segment (Count 1)
  # and only if we are moving to the Directory segment.
  if [[ $SEGMENT_COUNT -eq 1 ]]; then
    echo -n " %F{white}in%f"
  fi

  # First segment (Count 0) should have no leading space
  if [[ $SEGMENT_COUNT -eq 0 ]]; then
    echo -n "%{$bg%}%{$fg%}"
  else
    # Standard separator for all other segments (like Git)
    echo -n " %{$bg%}%{$fg%}"
  fi
  
  CURRENT_BG=$1
  SEGMENT_COUNT=$((SEGMENT_COUNT + 1))
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

git_toplevel() {
	local repo_root=$(git rev-parse --show-toplevel)
	if [[ $repo_root = '' ]]; then
		# We are in a bare repo. Use git dir as root
		repo_root=$(git rev-parse --git-dir)
		if [[ $repo_root = '.' ]]; then
			repo_root=$PWD
		fi
	fi
	echo -n $repo_root
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ "$USERNAME" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    local color="$AGNOSTER_CONTEXT_FG"
    # We explicitly re-set the color after the white @ to ensure 'arch' and 
    # the following segments don't turn white.
    prompt_segment "$AGNOSTER_CONTEXT_BG" "$color" "%(!.%{%F{$AGNOSTER_STATUS_ROOT_FG}%}.)%n%F{white}@%f%F{$color}arch"
  fi
}

prompt_git_relative() {
  local repo_root=$(git_toplevel)
  # Calculate path relative to the repo root
  local path_in_repo=$(pwd | sed "s/^$(echo "$repo_root" | sed 's:/:\\/:g;s/\$/\\$/g')//;s:^/::;s:/$::;")
  
  if [[ -n $path_in_repo ]]; then
    # Using 'NONE' background to keep it clean, or use AGNOSTER_DIR_BG
    # We add a thin separator  for a professional look
    prompt_segment "NONE" "$AGNOSTER_DIR_FG" " $path_in_repo"
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  (( $+commands[git] )) || return
  if [[ "$(command git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]]; then
    return
  fi
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\uf418'         #    
  }
  local ref dirty mode repo_path

   if [[ "$(command git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]]; then
    repo_path=$(command git rev-parse --git-dir 2>/dev/null)
    dirty=$(parse_git_dirty)
    ref=$(command git symbolic-ref HEAD 2> /dev/null) || \
    ref="◈ $(command git describe --exact-match --tags HEAD 2> /dev/null)" || \
    ref="➦ $(command git rev-parse --short HEAD 2> /dev/null)"
    
    # Logic for symbols (ahead/behind)
    if [[ $AGNOSTER_GIT_BRANCH_STATUS == 'true' ]]; then
      local ahead behind
      ahead=$(command git log --oneline @{upstream}.. 2>/dev/null)
      behind=$(command git log --oneline ..@{upstream} 2>/dev/null)
      if [[ -n "$ahead" ]] && [[ -n "$behind" ]]; then
        PL_BRANCH_CHAR=$'\u21c5'
      elif [[ -n "$ahead" ]]; then
        PL_BRANCH_CHAR=$'\u21b1'
      elif [[ -n "$behind" ]]; then
        PL_BRANCH_CHAR=$'\u21b0'
      fi
    fi

    # Logic for modes (Merge/Rebase)
    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr ''
    zstyle ':vcs_info:*' unstagedstr ''
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info

    # 1. Construct the content string first
    local git_content="${${ref:gs/%/%%}/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"

    # 2. Call prompt_segment ONCE with the content.
    # This prevents duplication and ensures the background covers the text.
    if [[ -n $dirty ]]; then
      prompt_segment "NONE" "$AGNOSTER_GIT_DIRTY_BG" "$git_content"
    else
      prompt_segment "NONE" "$AGNOSTER_GIT_DIRTY_BG" "$git_content"
    fi

    # 3. Handle the inline path if enabled
    [[ $AGNOSTER_GIT_INLINE == 'true' ]] && prompt_git_relative
  fi
}

prompt_bzr() {
  (( $+commands[bzr] )) || return

  # Test if bzr repository in directory hierarchy
  local dir="$PWD"
  while [[ ! -d "$dir/.bzr" ]]; do
    [[ "$dir" = "/" ]] && return
    dir="${dir:h}"
  done

  local bzr_status status_mod status_all revision
  if bzr_status=$(command bzr status 2>&1); then
    status_mod=$(echo -n "$bzr_status" | head -n1 | grep "modified" | wc -m)
    status_all=$(echo -n "$bzr_status" | head -n1 | wc -m)
    revision=${$(command bzr log -r-1 --log-format line | cut -d: -f1):gs/%/%%}
    if [[ $status_mod -gt 0 ]] ; then
      prompt_segment "$AGNOSTER_BZR_DIRTY_BG" "$AGNOSTER_BZR_DIRTY_FG" "bzr@$revision ✚"
    else
      if [[ $status_all -gt 0 ]] ; then
        prompt_segment "$AGNOSTER_BZR_DIRTY_BG" "$AGNOSTER_BZR_DIRTY_FG" "bzr@$revision"
      else
        prompt_segment "$AGNOSTER_BZR_CLEAN_BG" "$AGNOSTER_BZR_CLEAN_FG" "bzr@$revision"
      fi
    fi
  fi
}

prompt_hg() {
  (( $+commands[hg] )) || return
  local rev st branch
  if $(command hg id >/dev/null 2>&1); then
    if $(command hg prompt >/dev/null 2>&1); then
      if [[ $(command hg prompt "{status|unknown}") = "?" ]]; then
        # if files are not added
        prompt_segment "$AGNOSTER_HG_NEWFILE_BG" "$AGNOSTER_HG_NEWFILE_FG"
        st='±'
      elif [[ -n $(command hg prompt "{status|modified}") ]]; then
        # if any modification
        prompt_segment "$AGNOSTER_HG_CHANGED_BG" "$AGNOSTER_HG_CHANGED_FG"
        st='±'
      else
        # if working copy is clean
        prompt_segment "$AGNOSTER_HG_CLEAN_BG" "$AGNOSTER_HG_CLEAN_FG"
      fi
      echo -n ${$(command hg prompt "☿ {rev}@{branch}"):gs/%/%%} $st
    else
      st=""
      rev=$(command hg id -n 2>/dev/null | sed 's/[^-0-9]//g')
      branch=$(command hg id -b 2>/dev/null)
      if command hg st | command grep -q "^\?"; then
        prompt_segment "$AGNOSTER_HG_NEWFILE_BG" "$AGNOSTER_HG_NEWFILE_FG"
        st='±'
      elif command hg st | command grep -q "^[MA]"; then
        prompt_segment "$AGNOSTER_HG_CHANGED_BG" "$AGNOSTER_HG_CHANGED_FG"
        st='±'
      else
        prompt_segment "$AGNOSTER_HG_CLEAN_BG" "$AGNOSTER_HG_CLEAN_FG"
      fi
      echo -n "☿ ${rev:gs/%/%%}@${branch:gs/%/%%}" $st
    fi
  fi
}

# Dir: current working directory
prompt_dir() {
  if [[ $AGNOSTER_GIT_INLINE == 'true' ]] && $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    # Git repo and inline path enabled, hence only show the git root
    prompt_segment "$AGNOSTER_DIR_FG" "$(git_toplevel | sed "s:^$HOME:~:")"
  else
    prompt_segment "$AGNOSTER_DIR_BG" "$AGNOSTER_DIR_FG" '%~'
  fi
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    # AGNOSTER_GIT_DIRTY_BG is the yellow/orange color [cite: 11]
    prompt_segment "NONE" "#6ea8c4" "(${VIRTUAL_ENV:t})"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local -a symbols

  if [[ $AGNOSTER_STATUS_RETVAL_NUMERIC == 'true' ]]; then
    [[ $RETVAL -ne 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_RETVAL_FG}%}$RETVAL"
  else
    # Your  icon
    [[ $RETVAL -ne 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_RETVAL_FG}%}"
  fi
  [[ $UID -eq 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_ROOT_FG}%}⚡"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{$AGNOSTER_STATUS_JOB_FG}%}⚙"

  # Render on 'NONE' background at the far right
  [[ -n "$symbols" ]] && prompt_segment "NONE" "$AGNOSTER_STATUS_FG" "$symbols"
}

#AWS Profile:
# - display current AWS_PROFILE name
# - displays yellow on red if profile name contains 'production' or
#   ends in '-prod'
# - displays black on green otherwise
prompt_aws() {
  [[ -z "$AWS_PROFILE" || "$SHOW_AWS_PROMPT" = false ]] && return
  case "$AWS_PROFILE" in
    *-prod|*production*) prompt_segment "$AGNOSTER_AWS_PROD_BG" "$AGNOSTER_AWS_PROD_FG"  "AWS: ${AWS_PROFILE:gs/%/%%}" ;;
    *) prompt_segment "$AGNOSTER_AWS_BG" "$AGNOSTER_AWS_FG" "AWS: ${AWS_PROFILE:gs/%/%%}" ;;
  esac
}

prompt_terraform() {
  local terraform_info=$(tf_prompt_info)
  [[ -z "$terraform_info" ]] && return
  prompt_segment magenta yellow "TF: $terraform_info"
}

build_right_prompt() {
  RETVAL=$?
  local SEGMENT_COUNT=0
  local CURRENT_BG='NONE'

  prompt_status
}


## Main prompt
build_prompt() {
  RETVAL=$?
  SEGMENT_COUNT=0

  prompt_aws
  prompt_terraform
  prompt_context
  prompt_virtualenv
  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
      # Show ONLY the project root before the branch
      prompt_segment "$AGNOSTER_DIR_BG" "$AGNOSTER_DIR_FG" "$(git_toplevel | sed "s:^$HOME:~:") "
      # Show the branch and the sub-path
      prompt_git
    else
      # Standard behavior when outside of Git
      prompt_dir
  fi

  prompt_bzr
  prompt_hg
  prompt_end
}


RPROMPT='%B$(build_right_prompt)%b'
PROMPT='%B%F{$CURRENT_FG}╭─%f$(build_prompt) 
%b%F{$CURRENT_FG}╰─λ%f%b '

