#!/bin/bash

# 创建一个合并文件列表的临时文件
merge_list="merge_list.txt"
> "$merge_list"  # 清空或创建一个新的列表文件

# 遍历所有 mp4 格式的视频文件
for file in *.mp4; do
  # 检查文件是否存在，跳过不存在的文件
  if [[ ! -f "$file" ]]; then
    continue
  fi
  
  # 获取视频总时长（以秒为单位）
  duration=$(ffmpeg -i "$file" 2>&1 | grep "Duration" | awk '{print $2}' | tr -d , | awk -F: '{ print ($1 * 3600) + ($2 * 60) + $3 }')

  # 设置输出文件名的前缀
  prefix="${file%.mp4}"

  # 判断视频时长以选择裁剪方式
  if (( $(echo "$duration < 2" | bc -l) )); then
    # 如果视频少于 2 秒，删除视频
    echo "Deleting $file as it is shorter than 2 seconds."
    rm "$file"
    continue
  elif (( $(echo "$duration >= 2 && $duration < 6" | bc -l) )); then
    # 如果视频大于等于 2 秒且小于 6 秒，只保留前 2 秒
    first_duration=2
    ffmpeg -i "$file" -ss 0 -t "$first_duration" -c:v libx264 -crf 23 -preset veryfast -c:a aac "${prefix}_first_2sec.mp4"
    final_output="${prefix}_first_2sec.mp4"
  elif (( $(echo "$duration >= 6 && $duration < 10" | bc -l) )); then
    # 如果视频大于等于 6 秒且小于 10 秒，只保留前 6 秒
    first_duration=6
    ffmpeg -i "$file" -ss 0 -t "$first_duration" -c:v libx264 -crf 23 -preset veryfast -c:a aac "${prefix}_first_6sec.mp4"
    final_output="${prefix}_first_6sec.mp4"
  else
    # 如果视频大于等于 10 秒，只保留前 10 秒
    first_duration=10
    ffmpeg -i "$file" -ss 0 -t "$first_duration" -c:v libx264 -crf 23 -preset veryfast -c:a aac "${prefix}_first_10sec.mp4"
    final_output="${prefix}_first_10sec.mp4"
  fi

  # 如果裁剪成功，将裁剪后的文件名添加到合并列表
  if [[ -f "$final_output" ]]; then
    echo "file '$final_output'" >> "$merge_list"
  else
    echo "Error: Failed to create $final_output"
    continue
  fi

  # 删除原始视频
  rm "$file"
done

# 合并所有处理后的视频片段为一个最终的视频
final_output="merged_output.mp4"
if [[ -s "$merge_list" ]]; then
  ffmpeg -f concat -safe 0 -i "$merge_list" -c:v libx264 -crf 23 -preset veryfast -c:a aac "$final_output"
  
  # 检查合并是否成功
  if [[ -f "$final_output" ]]; then
    # 删除裁剪后的临时视频文件和合并列表文件
    rm *_first_2sec.mp4 *_first_6sec.mp4 *_first_10sec.mp4 "$merge_list"
  else
    echo "Error: Failed to create final merged video $final_output"
  fi
else
  echo "No video files to merge."
fi
