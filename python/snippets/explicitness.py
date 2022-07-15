def a_g(g2, l):
  n,c,g = l.split(",")
  if not n in g2:
    g2[n] = {}
  g2[n][c] = g

g = {}
with open("students.csv") as d:
  for l in d:
    a_g(g, l)


## versus ##

def add_student_grade(gradebook, name, course, grade):
  if not name in gradebook:
    gradebook[name] = {}
  gradebook[name][course] = grade

gradebook = {}
with open("students.csv") as students_grades:
  for row in students_grades:
    student_name, course, grade = row.split(",")
    add_student_grade(
      gradebook,
      student_name,
      course,
      grade
    )
