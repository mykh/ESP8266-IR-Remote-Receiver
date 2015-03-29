timerid= 1
pin = 4
code = 0
count = 0
pulse_prev_time = 0
pulse_prev_duration = 0

STATE_IDLE = 0
STATE_READING = 1
STATE_REPEAT = 2
state = STATE_IDLE

PULSE_0 = 0
PULSE_1 = 1
PULSE_START   = 2
PULSE_REPEAT  = 3
PULSE_UNKNOWN = 4

irCallback = nil

function isShortPulse(duration, negative)
  if (negative) then
    return (duration > -630) and (duration < -500)
  else
    return (duration > 500) and (duration < 630)
  end
end

function recognizePulse(prev, curr)
  pulse = PULSE_UNKNOWN
  if (prev > 8000) and (prev < 10000) then
    if (curr > -5000) and (curr < -4000) then
      pulse = PULSE_START
    elseif (curr > -2500) and (curr < -1750) then
      pulse = PULSE_REPEAT
    end
  elseif isShortPulse(prev) then
    if (curr > -1850) and (curr < -1600) then
      pulse = PULSE_1
    elseif isShortPulse(curr, true) then
      pulse = PULSE_0
    end
  end
  return pulse
end

function trgPulse(level)
  now = tmr.now()
  duration = now - pulse_prev_time
  if level == 1 then
    gpio.trig(pin, 'down')
  else
    duration = -duration;
    gpio.trig(pin, 'up')
  end
  
  if state == STATE_IDLE then
    pulse = recognizePulse(pulse_prev_duration, duration)
    if pulse == PULSE_START then
      code = 0
      count = 0
      state = STATE_READING
    elseif pulse == PULSE_REPEAT then
      state = STATE_REPEAT
    end
  elseif state == STATE_READING then
    count = count + 1
    if (count ~= 0) and (count % 2 == 0) then
      pulse = recognizePulse(pulse_prev_duration, duration)
      if (pulse == PULSE_0) or (pulse == PULSE_1) then
        code = code * 2 + pulse
      else
        -- ?calback
        --print('?code', code, 'pulse', pulse, 'prev', pulse_prev_duration, 'curr', duration, 'count', count)
        state = STATE_IDLE
      end
    elseif not isShortPulse(duration) then
      --print('NOT short', 'code', code, 'pulse', pulse, 'prev', pulse_prev_duration, 'curr', duration, 'count', count)
    end
  elseif state == STATE_REPEAT then
    if isShortPulse(duration) then
      code = -1
      --print('code', code, 'curr', duration, 'count', count)
      irCallback(code)
      code = 0
    else
      --print('!repeat')
    end
    state = STATE_IDLE
  end
  
  pulse_prev_time = now
  pulse_prev_duration = duration
  state_prev = state
end

function tmrPulse()
  if (tmr.now() - pulse_prev_time) > 10000 then
    if state == STATE_READING then
      --print('code', code, 'count', count)
      irCallback(code)
      code = 0
      state = STATE_IDLE
    end
  end
  tmr.alarm(timerid, 10, 0, tmrPulse)
end

function init(callback)
  irCallback = callback
  gpio.mode(pin, gpio.INT)
  gpio.trig(pin, 'down', trgPulse)
  tmrPulse()
end

-- example
init(function (code)
  print(code)
end)
